// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "src/RulesEngineIntegration.sol";

contract FortePerpsEngine is RulesEngineClientCustom {
    // ---------------------------
    // STRUCTS & ENUMS
    // ---------------------------
    enum PositionType {
        LONG,
        SHORT
    }

    struct Position {
        uint256 size; // Notional size in USD
        uint256 entryPrice; // Entry price in USD
        uint256 collateral; // Margin posted by trader
        uint256 leverage; // Leverage multiplier (e.g., 10 for 10x)
        PositionType positionType;
        uint256 lastFundingTime;
    }

    // ---------------------------
    // STATE VARIABLES
    // ---------------------------
    mapping(address => Position) public positions;
    mapping(address => uint256) public freeCollateral;

    uint256 public fundingRatePerHour = 10; // 0.01% = 10 basis points (bps)
    uint256 public maintenanceMarginRate = 167; // 1.67% = 167 bps
    uint256 public constant BPS_DIVISOR = 10000;

    // ---------------------------
    // ORACLE
    // ---------------------------
    IPriceOracle public oracle;

    constructor(address _oracle) {
        require(_oracle != address(0), "Invalid oracle address");
        oracle = IPriceOracle(_oracle);

        // Add initial free collateral for 5 test addresses
        // These are common test addresses - replace with actual addresses if needed
        address[5] memory testAddresses = [
            0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266, // Hardhat account 0
            0x70997970C51812dc3A010C7d01b50e0d17dc79C8, // Hardhat account 1
            0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC, // Hardhat account 2
            0x90F79bf6EB2c4f870365E785982E1f101E93b906, // Hardhat account 3
            0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65 // Hardhat account 4
        ];

        uint256 initialCollateral = 1000 * 10 ** 18; // 1000 USD in wei (assuming 18 decimals)

        for (uint i = 0; i < testAddresses.length; i++) {
            freeCollateral[testAddresses[i]] = initialCollateral;
        }
    }

    function setOracle(address _oracle) external {
        oracle = IPriceOracle(_oracle);
    }

    // ---------------------------
    // EVENTS
    // ---------------------------
    event PositionOpened(
        address indexed trader,
        uint256 size,
        uint256 entryPrice,
        uint256 collateral,
        uint256 leverage,
        PositionType positionType
    );
    event PositionClosed(
        address indexed trader,
        uint256 pnl,
        uint256 returnedCollateral
    );
    event PositionLiquidated(address indexed trader, uint256 pnl);
    event FundingApplied(address indexed trader, uint256 fundingPaid);
    event CollateralAdded(address indexed user, uint256 amount);

    // ---------------------------
    // MODIFIERS
    // ---------------------------
    modifier hasOpenPosition(address trader) {
        require(positions[trader].size > 0, "No open position");
        _;
    }

    // ---------------------------
    // CORE FUNCTIONS
    // ---------------------------

    function openPosition(
        uint256 _size,
        uint256 _collateral,
        uint256 _leverage,
        PositionType _positionType
    ) external {
        require(positions[msg.sender].size == 0, "Already have open position");
        require(_leverage > 0, "Leverage must be > 0");
        require(_collateral >= _size / _leverage, "Insufficient collateral");
        require(
            freeCollateral[msg.sender] >= _collateral,
            "Insufficient free collateral"
        );

        uint256 currentPrice = oracle.getPrice();
        positions[msg.sender] = Position({
            size: _size,
            entryPrice: currentPrice,
            collateral: _collateral,
            leverage: _leverage,
            positionType: _positionType,
            lastFundingTime: block.timestamp
        });

        freeCollateral[msg.sender] -= _collateral;

        emit PositionOpened(
            msg.sender,
            _size,
            currentPrice,
            _collateral,
            _leverage,
            _positionType
        );
    }

    function closePosition() external hasOpenPosition(msg.sender) {
        Position memory pos = positions[msg.sender];
        uint256 pnl = calculatePnL(pos);

        freeCollateral[msg.sender] += pos.collateral + pnl;
        delete positions[msg.sender];

        emit PositionClosed(msg.sender, pnl, pos.collateral);
    }

    function liquidatePosition(
        address _trader
    )
        external
        checkRulesBeforeliquidatePosition(_trader, positions[_trader].size)
    {
        require(isUnderCollateralized(_trader), "Position healthy");

        Position memory pos = positions[_trader];
        uint256 pnl = calculatePnL(pos);

        // Liquidate: no collateral returned beyond what remains after P&L
        freeCollateral[_trader] += pos.collateral + pnl;
        delete positions[_trader];

        emit PositionLiquidated(_trader, pnl);
    }

    function applyFunding(address _trader) public hasOpenPosition(_trader) {
        Position storage pos = positions[_trader];
        uint256 elapsedHours = (block.timestamp - pos.lastFundingTime) /
            1 hours;
        if (elapsedHours == 0) return;

        uint256 fundingPayment = (pos.size *
            fundingRatePerHour *
            elapsedHours) / BPS_DIVISOR;

        if (pos.positionType == PositionType.LONG) {
            pos.collateral -= fundingPayment;
        } else {
            pos.collateral += fundingPayment;
        }
        pos.lastFundingTime = block.timestamp;

        emit FundingApplied(_trader, fundingPayment);
    }

    // ---------------------------
    // COLLATERAL MANAGEMENT
    // ---------------------------

    function addCollateral(address _user, uint256 _amount) external {
        freeCollateral[_user] += _amount;
        emit CollateralAdded(_user, _amount);
    }

    function addCollateralForSelf(uint256 _amount) external {
        freeCollateral[msg.sender] += _amount;
        emit CollateralAdded(msg.sender, _amount);
    }

    function getFreeCollateral(address _user) external view returns (uint256) {
        return freeCollateral[_user];
    }

    // ---------------------------
    // HELPERS
    // ---------------------------

    function calculatePnL(Position memory pos) public returns (uint256 pnl) {
        uint256 currentPrice = oracle.getPrice();
        if (pos.positionType == PositionType.LONG) {
            pnl = ((currentPrice - pos.entryPrice) * pos.size) / pos.entryPrice;
        } else {
            pnl = ((pos.entryPrice - currentPrice) * pos.size) / pos.entryPrice;
        }
    }

    function isUnderCollateralized(address _trader) public returns (bool) {
        Position memory pos = positions[_trader];
        uint256 pnl = calculatePnL(pos);
        int256 equity = int256(pos.collateral) + int256(pnl);
        uint256 maintenanceMargin = (pos.size * maintenanceMarginRate) /
            BPS_DIVISOR;
        return equity < int256(maintenanceMargin);
    }

    // ---------------------------
    // ADMIN
    // ---------------------------

    // Remove updatePrice function, as price is now from oracle
}

interface IPriceOracle {
    function getPrice() external returns (uint256);
}
