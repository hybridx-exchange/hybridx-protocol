// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "../../deps/access/Ownable.sol";
import "../../deps/ERC721.sol";
import "../../deps/extensions/ERC721Enumerable.sol";
import "../../deps/extensions/ERC721Burnable.sol";
import "../../deps/access/AccessControlEnumerable.sol";
import "../../deps/utils/Context.sol";
import "../../deps/utils/Counters.sol";
import "../../deps/utils/Strings.sol";
import "../../deps/libraries/SafeMath.sol";
import "./interfaces/IOrderBook.sol";
import "./interfaces/IOrder.sol";

contract OrderNFT is
    Context,
    AccessControlEnumerable,
    ERC721Enumerable,
    ERC721Burnable,
    Ownable,
    IOrder {

    event OrderUpdate(uint256 indexed tokenId, uint256 offer1, uint256 remain1, uint256 offer2, uint256 remain2);

    using Counters for Counters.Counter;
    using SafeMath for uint256;
    using Strings for string;
    using Strings for address;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    Counters.Counter private _tokenIdTracker;
    string private _baseTokenURI = "";

    address public orderbook;
    mapping(uint => IOrder.OrderDetail) private orderDetails;
    constructor() ERC721("HybridX Order", "ORDER") {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _tokenIdTracker.increment();
    }

    function initialize(address _admin, address _orderbook) external override {
        _setupRole(DEFAULT_ADMIN_ROLE, _admin);
        _setupRole(MINTER_ROLE, _orderbook);
        orderbook = _orderbook;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    function symbol() public view virtual override returns (string memory) {
        return super.symbol()
        .concat("#")
        .concat(IOrderBook(orderbook).baseToken().toHexString())
        .concat("-")
        .concat(IOrderBook(orderbook).quoteToken().toHexString());
    }

    function add(uint256 tokenId, uint256 amount) external virtual override {
        require(hasRole(MINTER_ROLE, _msgSender()), "ORDER: must have minter role to mint");
        OrderDetail memory orderDetail = orderDetails[tokenId];
        require(orderDetail._price != 0, "ORDER: order must be exist");
        (uint256 offer, uint256 remain) = (orderDetail._offer.add(amount), orderDetail._remain.add(amount));
        emit OrderUpdate(tokenId, orderDetail._offer, orderDetail._remain, offer, remain);
        orderDetails[tokenId]._offer = offer;
        orderDetails[tokenId]._remain = remain;
    }

    function mint(OrderDetail memory orderDetail, address to) external virtual override returns (uint256 tokenId) {
        require(hasRole(MINTER_ROLE, _msgSender()), "ORDER: must have minter role to mint");
        tokenId = _tokenIdTracker.current();
        orderDetails[tokenId] = orderDetail;
        _mint(to, tokenId);
        _tokenIdTracker.increment();
    }

    function sub(uint256 tokenId, uint256 amount) external virtual override {
        require(hasRole(MINTER_ROLE, _msgSender()), "ORDER: must have minter role to burn");
        OrderDetail memory orderDetail = orderDetails[tokenId];
        require(orderDetail._price != 0, "ORDER: order must be exist");
        uint256 remain = orderDetail._remain.sub(amount);
        if (remain == 0) {
            delete(orderDetails[tokenId]);
            _burn(tokenId);
        }
        else {
            emit OrderUpdate(tokenId, orderDetail._offer, orderDetail._remain, orderDetail._offer, remain);
            orderDetails[tokenId]._remain = remain;
        }
    }

    function burn(uint256 tokenId) public virtual override {
        require(hasRole(MINTER_ROLE, _msgSender()), "ORDER: must have minter role to burn");
        OrderDetail memory orderDetail = orderDetails[tokenId];
        require(orderDetail._price != 0, "ORDER: order must be exist");
        delete(orderDetails[tokenId]);
        _burn(tokenId);
    }

    function get(uint256 _tokenId) public override view returns (OrderDetail memory order) {
        order = orderDetails[_tokenId];
    }

    function getUserOrders(address user) external view returns (uint[] memory ids, OrderDetail[] memory orders) {
        uint balance = balanceOf(user);
        if (balance > 0) {
            orders = new OrderDetail[](balance);
            ids = new uint[](balance);
            for (uint i = 0; i < balance; i++) {
                ids[i] = tokenOfOwnerByIndex(user, i);
                orders[i] = orderDetails[ids[i]];
            }
        }
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal virtual
        override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual
        override(AccessControlEnumerable, ERC721, ERC721Enumerable)
    returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}