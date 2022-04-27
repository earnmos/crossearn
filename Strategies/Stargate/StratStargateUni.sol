// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "./StratStargateBase.sol";
import "../../Interfaces/Uniswap/IUniswapRouter.sol";

contract StratStargateUni is StratStargateBase {
    IUniswapRouter public uniRouter;

    // path
    address[] public stgToUnderlying;

    function _setParamsInternal(bytes calldata _data) internal override {
        address _uniRouter = abi.decode(_data, (address));

        uniRouter = IUniswapRouter(_uniRouter);
        stgToUnderlying = [address(stargate), address(underlyingToken)];
    }

    /**
     * @dev Updates router that will be used for swaps.
     * @param _uniRouter new unirouter address.
     */
    function setUnirouter(address _uniRouter) external onlyManager {
        uniRouter = IUniswapRouter(_uniRouter);
    }

    function _swapStargateToUnderlying(uint256 _stargateBal) internal override {
        uniRouter.swapExactTokensForTokens(
            _stargateBal,
            0,
            stgToUnderlying,
            address(this),
            now
        );
    }

    function _giveExtraAllowances() internal override {
        stargate.safeApprove(address(uniRouter), uint256(-1));
    }

    function _removeExtraAllowances() internal override {
        stargate.safeApprove(address(uniRouter), 0);
    }
}
