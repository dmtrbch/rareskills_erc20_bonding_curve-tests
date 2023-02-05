// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./BancorBondingCurve.sol";

/// @title ERC20 Bonding Curve Token
/// @author Dimitar Bochvaroski
/// @notice Token sale and buyback with bonding curve. The more tokens a user buys, the more expensive the token becomes.
contract BctToken is BancorBondingCurve, ERC20, ERC20Burnable, Ownable {
    uint256 private constant SCALE = 10**18;
    uint256 private constant WITHDRAWAL_FEE = 1000;
    uint256 private constant DENOMINATOR = 10_000;
    uint256 private constant RESERVE_RATIO = 500_000;
    uint256 private constant INITIAL_TOKEN_SUPPLY = 100_000;

    /**
     * @notice Balance of the reserve token, in our case ETH
     * @dev Amount of ETH reserve is represented in wei (10**18)
     * User can send ETH to the contract to get BCT token and vice versa
     */
    uint256 public reserveBalance = 200 * SCALE;

    /// @notice Total amount of the fee that is generated with every BCT token sale
    uint256 public totalFee;

    /**
     * @dev Passes the values for the {name} and {symbol} parameters, required for
     * the ERC20 token implementation from OpenZeppelin.
     *
     * Mints the initial token supply of BCT
     */
    constructor() ERC20("Bonding Curve Token", "BCT") {
        _mint(msg.sender, INITIAL_TOKEN_SUPPLY * SCALE);
    }

    /**
     * @dev Called when BCT token is bought
     *
     * Mints new BCT tokens, increases the supply
     */
    function mint() public payable {
        require(msg.value > 0, "ERC20: Must send ether to buy tokens.");
        _continuousMint(msg.value);
    }

    /**
     * @dev Called when BCT token is sold
     *
     * Burns BCT tokens, decreases the supply
     */
    function burn(uint256 _amount) public override {
        uint256 returnAmount = _continuousBurn(_amount);
        (bool success, ) = msg.sender.call{value: returnAmount}("");
        require(success, "ERC20: Token sell failed.");
    }

    /**
     * @notice Allow the owner to withdraw the total amount of fee generated while BCT token is sold
     * @dev sends the `totalFee` amount to the owner of the contract
     * `tmpFee` is used to take snapshot of the `totalFee` and mitigate re-entrancy attacks
     */
    function withdrawFee() external onlyOwner {
        require(totalFee > 0, "ERC20: No fees for withdrawal.");
        uint256 tmpFee = totalFee;
        totalFee = 0;
        (bool success, ) = msg.sender.call{value: tmpFee}("");
        require(success, "ERC20: Fee withdrawal failed.");
    }

    /**
     * @notice Calculates the amount of BCT token that the address should receive after sending ETH
     *
     * @dev Makes use of the Bancor formula: given a continuous token supply, reserve token balance, reserve ratio, and a deposit amount (in the reserve token),
     * calculates the return for a given conversion (in the continuous token)
     *
     * @param _amount amount of ETH sent to buy BCT token
     *
     * @return mintAmount amount of BCT tokens bough
     */
    function calculateContinuousMintReturn(uint256 _amount)
        public
        view
        returns (uint256 mintAmount)
    {
        return
            calculatePurchaseReturn(
                totalSupply(),
                reserveBalance,
                uint32(RESERVE_RATIO),
                _amount
            );
    }

    /**
     * @notice Calculates the amount of ETH that the address should receive after selling BCT
     *
     * @dev Makes use of the Bancor formula: given a continuous token supply, reserve token balance, reserve ratio and a sell amount (in the continuous token),
     * calculates the return for a given conversion (in the reserve token)
     *
     * @param _amount amount of BCT sent/burnt to receive ETH
     *
     * @return burnAmount amount of ETH received
     */
    function calculateContinuousBurnReturn(uint256 _amount)
        public
        view
        returns (uint256 burnAmount)
    {
        return
            calculateSaleReturn(
                totalSupply(),
                reserveBalance,
                uint32(RESERVE_RATIO),
                _amount
            );
    }

    /**
     * @notice Calculating the price of the BCT token when new tokens are bought with the help of additional functions
     *
     * @dev makes use of the calculateContinuousMintReturn function to calculate the price of BCT token, and sends BCT token amount to the `msg.sender`
     *
     * @param _deposit amount of ETH sent to buy BCT
     *
     * @return amount amount of BCT tokens received
     */
    function _continuousMint(uint256 _deposit) internal returns (uint256) {
        require(_deposit > 0, "ERC20: Deposit must be non-zero.");

        uint256 amount = calculateContinuousMintReturn(_deposit);
        _mint(msg.sender, amount);
        reserveBalance += _deposit;
        return amount;
    }

    /**
     * @notice Calculating the price of the BCT token when tokens are sold with the help of additional functions
     *
     * @dev makes use of the calculateContinuousBurnReturn function to calculate the price of BCT token, and sends the respective amount in ETH to the `msg.sender`
     * Users are selling BCT token with 10% loss
     *
     * @param _amount amount of BCT sold to receive ETH
     *
     * @return reimburseAmount ETH received after fees
     */
    function _continuousBurn(uint256 _amount) internal returns (uint256) {
        require(_amount > 0, "ERC20: Amount must be non-zero.");
        require(
            balanceOf(msg.sender) >= _amount,
            "ERC20: Insufficient tokens to burn."
        );

        uint256 reimburseAmount = calculateContinuousBurnReturn(_amount);
        reserveBalance -= reimburseAmount;

        uint256 fee = _calculateFee(reimburseAmount);
        totalFee += fee;

        _burn(msg.sender, _amount);
        return reimburseAmount - fee;
    }

    /**
     * @notice Calculating the loss after selling BCT token
     *
     * @dev Basis Points are used to calculate the percentage, since Floating and Fixed-Point numbers can't be expressed in Solidity
     * Multiply first before doing the division.
     * Doing the division first can result in values being rounded down to 0 before the multiplication is applied which will cause a multiplication by 0.
     *
     * @param _amount - amount of ETH that percentage is calculated from
     *
     * @return _amount * WITHDRAWAL_FEE / DENOMINATOR - 10% of `_amount`
     */
    function _calculateFee(uint256 _amount) internal pure returns (uint256) {
        require(
            (_amount * WITHDRAWAL_FEE) >= DENOMINATOR,
            "ERC20: Token sell amount must be bigger."
        );
        return (_amount * WITHDRAWAL_FEE) / DENOMINATOR;
    }

    /**
     * @dev In case transaction without data and with ETH amount is sent to the smart contract
     * call the function to `mint()` new tokens for that amount of ETH
     */
    receive() external payable {
        mint();
    }
}
