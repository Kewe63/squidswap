// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract SquidTokenFactory is ReentrancyGuard {
    using SafeMath for uint256;

    address[] public deployedTokens;
    address public constant SQUIDS_TOKEN = 0xbf0cAfCbaaF0be8221Ae8d630500984eDC908861;
    uint256 public requiredTokens = 150_000 * 10**18;

    address public owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function setRequiredTokens(uint256 _newAmount) external onlyOwner {
        requiredTokens = _newAmount;
    }

    event TokenCreated(
        address tokenAddress,
        string name,
        string symbol,
        string description,
        string image,
        string twitter,
        string telegram,
        string website,
        address developer
    );

    struct TokenInfo {
        address tokenAddress;
        string name;
        string symbol;
        string description;
        string image;
        string twitter;
        string telegram;
        string website;
        address developer;
        uint256 launchTime;
        bool isActive;
        uint256 ethBalance;
        uint256 tokenBalance;
    }

    mapping(address => TokenInfo) public tokenInfo;
    mapping(uint256 => address) public tokenByIndex;
    uint256 public totalTokens;

    mapping(address => uint256) public tokensPerWallet;
    uint256 constant MAX_TOKENS = 10;

    function createToken(
        string memory name,
        string memory symbol,
        string memory description,
        string memory image,
        string memory twitter,
        string memory telegram,
        string memory website
    ) public nonReentrant {
        require(tokensPerWallet[msg.sender] < MAX_TOKENS, "Max tokens exceeded");
        IERC20 squidToken = IERC20(SQUIDS_TOKEN);
        require(squidToken.balanceOf(msg.sender) >= requiredTokens, "Must hold required tokens");

        SquidTokenLaunch newToken = new SquidTokenLaunch(
            name, symbol, description, image, twitter, telegram, website, msg.sender
        );
        address tokenAddress = address(newToken);

        tokenInfo[tokenAddress] = TokenInfo({
            tokenAddress: tokenAddress,
            name: name,
            symbol: symbol,
            description: description,
            image: image,
            twitter: twitter,
            telegram: telegram,
            website: website,
            developer: msg.sender,
            launchTime: block.timestamp,
            isActive: true,
            ethBalance: 0,
            tokenBalance: 0
        });

        tokenByIndex[totalTokens] = tokenAddress;
        totalTokens++;

        deployedTokens.push(tokenAddress);
        tokensPerWallet[msg.sender]++;

        emit TokenCreated(
            tokenAddress, name, symbol, description, image, twitter, telegram, website, msg.sender
        );
    }

    function getDeployedTokens() public view returns (address[] memory) {
        return deployedTokens;
    }

    function getTokensPaginated(uint256 start, uint256 size)
        external
        view
        returns (TokenInfo[] memory tokens, uint256 total)
    {
        uint256 end = start + size;
        if (end > totalTokens) {
            end = totalTokens;
        }

        tokens = new TokenInfo[](end - start);
        for (uint256 i = start; i < end; i++) {
            TokenInfo memory token = tokenInfo[tokenByIndex[i]];
            token.ethBalance = address(token.tokenAddress).balance;
            token.tokenBalance = IERC20(token.tokenAddress).balanceOf(token.tokenAddress);
            tokens[i - start] = token;
        }

        return (tokens, totalTokens);
    }
}

contract SquidTokenLaunch is Context, IERC20, Ownable, ReentrancyGuard {
    using SafeMath for uint256;

    string private _name;
    string private _symbol;
    uint8 private constant _decimals = 18;
    uint256 private _totalSupply;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    address public developer;

    constructor(
        string memory name,
        string memory symbol,
        string memory description,
        string memory image,
        string memory twitter,
        string memory telegram,
        string memory website,
        address _developer
    ) {
        _name = name;
        _symbol = symbol;
        developer = _developer;

        _mint(address(this), 1_000_000_000 * 10**_decimals);
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public pure returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount) public override nonReentrant returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override nonReentrant returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(
            sender,
            _msgSender(),
            _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance")
        );
        return true;
    }

    function _transfer(address sender, address recipient, uint256 amount) internal {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _balances[sender] = _balances[sender].sub(amount, "ERC20: transfer amount exceeds balance");
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
    }

    function _mint(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: mint to the zero address");

        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
}
