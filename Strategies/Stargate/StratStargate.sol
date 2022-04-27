// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "./StratStargateBase.sol";
import "../../Interfaces/Curve/ICurveStableSwap.sol";

contract StratStargate is StratStargateBase {
    struct CurvePoolConfig {
        address pool;
        bool is128;
        int128 i;
        int128 j;
    }
    // curve routes
    CurvePoolConfig[] public stargateToWantRoute;

    function _setParamsInternal(bytes calldata _data) internal override {
        (
            address[] memory _pools,
            bool[] memory _is128,
            int128[] memory _i,
            int128[] memory _j
        ) = abi.decode(_data, (address[], bool[], int128[], int128[]));

        _checkRoute(_pools, _i, _j);
        for (uint256 index; index < _pools.length; index++) {
            stargateToWantRoute.push(
                CurvePoolConfig({
                    pool: _pools[index],
                    is128: _is128[index],
                    i: _i[index],
                    j: _j[index]
                })
            );
        }
    }

    function _checkRoute(
        address[] memory _pools,
        int128[] memory _i,
        int128[] memory _j
    ) internal view {
        require(
            _pools.length > 0 &&
                _pools.length == _i.length &&
                _pools.length == _j.length,
            "invalid _pools or _i or _j"
        );
        address token = address(stargate);
        for (uint256 index; index < _pools.length; index++) {
            ICurveStableSwap pool = ICurveStableSwap(_pools[index]);
            require(token == pool.coins(uint256(_i[index])), "invalid route");
            token = pool.coins(uint256(_j[index]));
        }
        require(token == address(underlyingToken), "invalid route");
    }

    function _swapStargateToUnderlying(uint256 _stargateBal) internal override {
        if (_estimateSwappedUnderlying(_stargateBal) == 0) {
            return;
        }
        uint256 amount = _stargateBal;
        for (uint256 index; index < stargateToWantRoute.length; index++) {
            CurvePoolConfig memory config = stargateToWantRoute[index];
            IERC20 coin = IERC20(
                ICurveStableSwap(config.pool).coins(uint256(config.j))
            );
            uint256 coinBalBefore = coin.balanceOf(address(this));
            if (config.is128) {
                ICurveStableSwap128(config.pool).exchange(
                    config.i,
                    config.j,
                    amount,
                    0
                );
            } else {
                ICurveStableSwap256(config.pool).exchange(
                    uint256(config.i),
                    uint256(config.j),
                    amount,
                    0
                );
            }
            uint256 coinBalAfter = coin.balanceOf(address(this));
            amount = coinBalAfter.sub(coinBalBefore);
            if (amount == 0) {
                break;
            }
        }
    }

    function _estimateSwappedUnderlying(uint256 _stargateBal)
        internal
        view
        returns (uint256)
    {
        if (_stargateBal == 0) {
            return 0;
        }
        uint256 amount = _stargateBal;
        for (uint256 index; index < stargateToWantRoute.length; index++) {
            CurvePoolConfig memory config = stargateToWantRoute[index];
            if (config.is128) {
                amount = ICurveStableSwap128(config.pool).get_dy(
                    config.i,
                    config.j,
                    amount
                );
            } else {
                amount = ICurveStableSwap256(config.pool).get_dy(
                    uint256(config.i),
                    uint256(config.j),
                    amount
                );
            }
            if (amount == 0) {
                break;
            }
        }
        return amount;
    }

    function _giveExtraAllowances() internal override {
        for (uint256 index; index < stargateToWantRoute.length; index++) {
            CurvePoolConfig memory config = stargateToWantRoute[index];
            IERC20(ICurveStableSwap(config.pool).coins(uint256(config.i)))
                .safeApprove(address(config.pool), uint256(-1));
        }
    }

    function _removeExtraAllowances() internal override {
        for (uint256 index; index < stargateToWantRoute.length; index++) {
            CurvePoolConfig memory config = stargateToWantRoute[index];
            IERC20(ICurveStableSwap(config.pool).coins(uint256(config.i)))
                .safeApprove(address(config.pool), 0);
        }
    }
}
