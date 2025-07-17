// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MockPriceOracle {
    uint256 public currentPrice; // 2 decimal price representing USD so 100K = 100_000_00
    int256 public minStep; //
    int256 public maxStep;
    uint256 public lastUpdate;

    constructor(uint256 _initialPrice, int256 _minStep, int256 _maxStep) {
        require(
            _minStep <= _maxStep,
            "Invalid range: minStep must be <= maxStep"
        );
        currentPrice = _initialPrice;
        minStep = _minStep;
        maxStep = _maxStep;
        lastUpdate = block.timestamp;
    }

    function getPrice() external returns (uint256) {
        // Always update the price, use minimum 1 second elapsed
        uint256 timeElapsed = block.timestamp > lastUpdate
            ? block.timestamp - lastUpdate
            : 1;

        // Generate random step within range, scaled by time elapsed
        int256 randomStep = _getRandomStep(timeElapsed);

        if (randomStep >= 0) {
            currentPrice += uint256(randomStep);
        } else {
            uint256 absStep = uint256(-randomStep);
            if (currentPrice > absStep) {
                currentPrice -= absStep;
            } else {
                currentPrice = 1; // avoid zero
            }
        }
        lastUpdate = block.timestamp;

        return currentPrice;
    }

    function _getRandomStep(
        uint256 timeElapsed
    ) internal view returns (int256) {
        // Use block data for pseudo-randomness
        uint256 random = uint256(
            keccak256(
                abi.encodePacked(
                    block.timestamp,
                    block.prevrandao,
                    block.number,
                    currentPrice,
                    timeElapsed
                )
            )
        );

        // Scale the step range by time elapsed (e.g., 1 second = 1x, 10 seconds = 10x)
        // You can adjust this scaling factor as needed
        uint256 scaledRange = uint256(maxStep - minStep + 1) * timeElapsed;
        int256 randomOffset = int256(random % scaledRange);

        // Map back to the original range but scaled by time
        int256 scaledStep = minStep +
            int256(uint256(randomOffset) / timeElapsed);

        return scaledStep;
    }

    function setPrice(uint256 _price) external {
        currentPrice = _price;
    }
}
