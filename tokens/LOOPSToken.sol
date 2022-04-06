// SPDX-License-Identifier: MIT

pragma solidity ^0.8.2;
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

interface IRouter1 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH);
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountToken, uint amountETH);
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
    external
    payable
    returns (uint[] memory amounts);
    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
    external
    returns (uint[] memory amounts);
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
    external
    returns (uint[] memory amounts);
    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
    external
    payable
    returns (uint[] memory amounts);

    function quote(uint amountA, uint reserveA, uint reserveB) external pure returns (uint amountB);
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut);
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure returns (uint amountIn);
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
}

interface IRouter2 is IRouter1 {
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountETH);
    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountETH);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}
interface ILoopsFactory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);

    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function allPairs(uint) external view returns (address pair);
    function allPairsLength() external view returns (uint);

    function createPair(address tokenA, address tokenB) external returns (address pair);

    function setFeeTo(address) external;
    function setFeeToSetter(address) external;
}
// LoopsToken with Governance.
contract LoopsToken is ERC20Upgradeable, OwnableUpgradeable {
    uint constant public MAX_SUPPLY = 100_000_000 ether;
    // Burn address
    address public BURN_ADDRESS;
    // Max amount to burn: 50% supply
    uint constant public MAX_AMOUNT_TO_BURN = 50_000_000 ether;
    address public loopsTokenStrategy;
    // Transfer tax rate. (default 8%)
    uint16 public transferTaxRate;
    // Burn rate % of tx. (default 2%).
    uint16 public burnRate;
    uint16 public LPRate;
    // Max transfer tax rate: 10%.
    uint16 public MAXIMUM_TRANSFER_TAX_RATE;

    // Max transfer amount rate in basis points. (default is 0.5% of total supply)
    uint16 public maxTransferAmountRate;
    // Addresses that excluded from antiWhale
    mapping(address => bool) public _excludedFromAntiWhale;
    // Addresses that excluded from tax
    mapping(address => bool) public _excludedFromTax;
    // The swap router, modifiable. Will be changed to LOOPSSwap's router when our own AMM release
    IRouter2 public loopsSwapRouter;
    // The trading pair
    address public LOOPSSwapPair;
    // Min amount to liquify. (default 500 LOOPS)
    uint public minAmountToLiquify;
    // The operator can only update the transfer tax rate
    address private _operator;
    // In swap and liquify
    bool private _inSwapAndLiquify;

    // Events
    event OperatorTransferred(address indexed previousOperator, address indexed newOperator);
    event TransferTaxRateUpdated(address indexed operator, uint previousRate, uint newRate);
    event MaxTransferAmountRateUpdated(address indexed operator, uint previousRate, uint newRate);
    event SetloopsTokenStrategy(address _by, address _loopsTokenStrategy);
    event SwapAndLiquify(uint tokensSwapped, uint ethReceived, uint tokensIntoLiqudity);
    event MinAmountToLiquifyUpdated(address indexed operator, uint previousAmount, uint newAmount);
    event loopsSwapRouterUpdated(address indexed operator, address indexed router, address indexed pair);

    modifier onlyOperator() {
        require(owner() == msg.sender || _operator == msg.sender, "operator: caller is not the operator");
        _;
    }

    modifier antiWhale(address sender, address recipient, uint amount) {
        if (maxTransferAmount() > 0) {
            if (
                _excludedFromAntiWhale[sender] == false
                && _excludedFromAntiWhale[recipient] == false
            ) {
                require(amount <= maxTransferAmount(), "LOOPS::antiWhale: Transfer amount exceeds the maxTransferAmount");
            }
        }
        _;
    }

    modifier transferTaxFree {
        uint16 _transferTaxRate = transferTaxRate;
        transferTaxRate = 0;
        _;
        transferTaxRate = _transferTaxRate;
    }
    modifier lockTheSwap {
        _inSwapAndLiquify = true;
        _;
        _inSwapAndLiquify = false;
    }

    /**
     * @dev Update the swap router.
     * Can only be called by the current operator.
     */
    function updateloopsSwapRouter(address _router) public onlyOperator {
        loopsSwapRouter = IRouter2(_router);
        LOOPSSwapPair = ILoopsFactory(loopsSwapRouter.factory()).getPair(address(this), loopsSwapRouter.WETH());
        require(LOOPSSwapPair != address(0), "LOOPS::updateloopsSwapRouter: Invalid pair address.");
        _excludedFromTax[LOOPSSwapPair] = true;
        _excludedFromAntiWhale[_router] = true;
        emit loopsSwapRouterUpdated(msg.sender, address(loopsSwapRouter), LOOPSSwapPair);
    }
    function initialize(address _loopsTokenStrategy) external virtual initializer {
        loopsTokenStrategy = _loopsTokenStrategy;
        transferTaxRate = 300;
        MAXIMUM_TRANSFER_TAX_RATE = 1000;
        BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;
        burnRate = 25;
        LPRate = 25;
        maxTransferAmountRate = 50;
        minAmountToLiquify = 500 ether;
        __ERC20_init("Loopstarter","LOOPS");
        _mint(_msgSender(), MAX_SUPPLY);
        __Ownable_init();
        _operator = _msgSender();
        emit OperatorTransferred(address(0), _operator);

        _excludedFromAntiWhale[msg.sender] = true;
        _excludedFromAntiWhale[address(0)] = true;
        _excludedFromAntiWhale[address(this)] = true;
        _excludedFromAntiWhale[BURN_ADDRESS] = true;

        _excludedFromTax[msg.sender] = true;
        _excludedFromTax[loopsTokenStrategy] = true;
        _excludedFromTax[address(this)] = true;
    }
    function setPercent(uint16 _percent2burn, uint16 _percent2addLP) external onlyOwner {
        require(_percent2addLP + _percent2burn <= 100, "LOOPS::setPercent: Invalid percent.");
        burnRate = _percent2burn;
        LPRate = _percent2addLP;
    }
    /**
     * @dev Update the min amount to liquify.
     * Can only be called by the current operator.
     */
    function updateMinAmountToLiquify(uint _minAmount) public onlyOperator {
        emit MinAmountToLiquifyUpdated(msg.sender, minAmountToLiquify, _minAmount);
        minAmountToLiquify = _minAmount;
    }
    function setloopsTokenStrategy(address _loopsTokenStrategy) external onlyOperator {
        loopsTokenStrategy = _loopsTokenStrategy;
        emit SetloopsTokenStrategy(_msgSender(), _loopsTokenStrategy);
    }
    function taxBaseOnAmount(uint _transferAmount) public view returns(uint) {
        return _transferAmount * transferTaxRate / 10000;
    }
    /// @dev overrides transfer function to meet tokenomics of LOOPS
    function _transfer(address sender, address recipient, uint amount) internal virtual override antiWhale(sender, recipient, amount) {

        if (_excludedFromTax[sender] || recipient == BURN_ADDRESS || transferTaxRate == 0) {
            super._transfer(sender, recipient, amount);
        } else {
            // default tax is 8% of every transfer
            uint taxAmount = taxBaseOnAmount(amount);
            uint burnAmount = taxAmount * burnRate / 100;
            uint liquidityAmount = taxAmount * LPRate / 100;

            // default 92% of transfer sent to recipient
            uint remaintaxAmount = taxAmount - burnAmount - liquidityAmount;
            uint sendAmount = amount - taxAmount;

            if(remaintaxAmount > 0) super._transfer(sender, loopsTokenStrategy, remaintaxAmount);

            super._transfer(sender, BURN_ADDRESS, burnAmount);
            super._transfer(sender, address(this), liquidityAmount);
            super._transfer(sender, recipient, sendAmount);
        }
    }
    /// @dev Swap and liquify
    function swapAndLiquify(uint ETHExpect, uint amountTokenMin2LP, uint amountETHMin2LP) external lockTheSwap transferTaxFree onlyOwner{
        require(!_inSwapAndLiquify, "LoopsToken::swapAndLiquify:Adding");
        require(address(loopsSwapRouter) != address(0), "LoopsToken::swapAndLiquify:router invalid");

        uint contractTokenBalance = balanceOf(address(this));
        uint _maxTransferAmount = maxTransferAmount();
        contractTokenBalance = contractTokenBalance > _maxTransferAmount ? _maxTransferAmount : contractTokenBalance;

        if (contractTokenBalance >= minAmountToLiquify) {
            // only min amount to liquify
            uint liquifyAmount = minAmountToLiquify;

            // split the liquify amount into halves
            uint half = liquifyAmount / 2;
            uint otherHalf = liquifyAmount - half;

            // capture the contract's current ETH balance.
            // this is so that we can capture exactly the amount of ETH that the
            // swap creates, and not make the liquidity event include any ETH that
            // has been manually sent to the contract
            uint initialBalance = address(this).balance;

            // swap tokens for ETH
            swapTokensForEth(half, ETHExpect);

            // how much ETH did we just swap into?
            uint newBalance = address(this).balance - initialBalance;

            // add liquidity
            addLiquidity(otherHalf, newBalance, amountTokenMin2LP, amountETHMin2LP);

            emit SwapAndLiquify(half, newBalance, otherHalf);
        }
    }

    /// @dev Swap tokens for eth
    function swapTokensForEth(uint tokenAmount, uint ETHExpect) private {
        // generate the LOOPSSwap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = loopsSwapRouter.WETH();

        _approve(address(this), address(loopsSwapRouter), tokenAmount);

        // make the swap
        loopsSwapRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            ETHExpect,
            path,
            address(this),
            block.timestamp
        );
    }

    /// @dev Add liquidity
    function addLiquidity(uint tokenAmount, uint ethAmount, uint amountTokenMin, uint amountETHMin) private {
        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(loopsSwapRouter), tokenAmount);

        // add the liquidity
        loopsSwapRouter.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            amountTokenMin,
            amountETHMin,
            operator(),
            block.timestamp
        );
    }
    /**
     * @dev Returns the max transfer amount.
     */
    function maxTransferAmount() public view returns (uint) {
        return totalSupply() * maxTransferAmountRate / 10000;
    }

    // To receive BNB from loopsSwapRouter when swapping
    receive() external payable {}

    /**
     * @dev Update the transfer tax rate.
     * Can only be called by the current operator.
     */
    function updateTransferTaxRate(uint16 _transferTaxRate) external onlyOperator {
        require(_transferTaxRate <= MAXIMUM_TRANSFER_TAX_RATE, "LOOPS::updateTransferTaxRate: Transfer tax rate must not exceed the maximum rate.");
        emit TransferTaxRateUpdated(msg.sender, transferTaxRate, _transferTaxRate);
        transferTaxRate = _transferTaxRate;
    }

    /**
     * @dev Update the max transfer amount rate.
     * Can only be called by the current operator.
     */
    function updateMaxTransferAmountRate(uint16 _maxTransferAmountRate) external onlyOperator {
        require(_maxTransferAmountRate <= 10000, "LOOPS::updateMaxTransferAmountRate: Max transfer amount rate must not exceed the maximum rate.");
        emit MaxTransferAmountRateUpdated(msg.sender, maxTransferAmountRate, _maxTransferAmountRate);
        maxTransferAmountRate = _maxTransferAmountRate;
    }

    /**
     * @dev Exclude or include an address from antiWhale.
     * Can only be called by the current operator.
     */
    function setExcludedFromAntiWhale(address _account, bool _excluded) external onlyOperator {
        _excludedFromAntiWhale[_account] = _excluded;
    }

    /**
     * @dev Exclude or include an address from tax.
     * Can only be called by the current operator.
     */
    function setExcludedFromTax(address _account, bool _excluded) external onlyOperator {
        _excludedFromTax[_account] = _excluded;
    }

    /**
     * @dev Returns the address of the current operator.
     */
    function operator() public view returns (address) {
        return _operator;
    }

    /**
     * @dev Transfers operator of the contract to a new account (`newOperator`).
     * Can only be called by the current operator.
     */
    function transferOperator(address newOperator) external onlyOperator {
        require(newOperator != address(0), "LOOPS::transferOperator: new operator is the zero address");
        emit OperatorTransferred(_operator, newOperator);
        _operator = newOperator;
    }
}