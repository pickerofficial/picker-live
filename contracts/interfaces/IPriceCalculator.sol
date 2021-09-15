// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

interface IPriceCalculator {
    struct ReferenceData {
        uint lastData;
        uint lastUpdated;
    }

    function pricesInUSD(address[] memory assets) external view returns (uint[] memory);

    function valueOfAsset(address asset, uint amount) external view returns (uint valueInBNB, uint valueInUSD);

    function unsafeValueOfAsset(address asset, uint amount) external view returns (uint valueInBNB, uint valueInUSD);

    function priceOfBunny() external view returns (uint);

    function priceOfBNB() external view returns (uint);

    function setPrices(address[] memory assets, uint[] memory prices) external;
}
