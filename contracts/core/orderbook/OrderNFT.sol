// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "../../deps/access/Ownable.sol";
import "../../deps/ERC721.sol";
import "../../deps/extensions/ERC721Enumerable.sol";
import "../../deps/extensions/ERC721Burnable.sol";
import "../../deps/access/AccessControlEnumerable.sol";
import "../../deps/utils/Context.sol";
import "../../deps/utils/Counters.sol";
import "../../deps/libraries/SafeMath.sol";
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

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    Counters.Counter private _tokenIdTracker;
    string private _baseTokenURI = "";

    address public orderbook;
    mapping(uint => OrderDetail) public override getOrderDetail;
    mapping(address => mapping(uint => uint)) private userOrderAtPrice;
    constructor(address _orderbook) ERC721("HybridX Order", "ORDER") {
        orderbook = _orderbook;
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(MINTER_ROLE, _orderbook);
        _tokenIdTracker.increment();
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    function mint(OrderDetail memory orderDetail, address to) external virtual override returns (uint256 tokenId) {
        require(hasRole(MINTER_ROLE, _msgSender()), "ORDER: must have minter role to mint");
        tokenId = userOrderAtPrice[to][orderDetail._price];
        if (tokenId != 0) {
            _add(tokenId, orderDetail._offer, orderDetail._remain);
        } else {
            tokenId = _tokenIdTracker.current();
            getOrderDetail[tokenId] = orderDetail;
            userOrderAtPrice[to][orderDetail._price] = tokenId;
            _mint(to, tokenId);
            _tokenIdTracker.increment();
        }
    }

    function burn(uint256 tokenId, uint256 amount) public virtual override {
        require(hasRole(MINTER_ROLE, _msgSender()), "ORDER: must have minter role to burn");
        OrderDetail memory orderDetail = getOrderDetail[tokenId];
        address to = ownerOf(tokenId);
        require(orderDetail._price != 0, "ORDER: order must be exist");
        uint256 remain = orderDetail._remain.sub(amount);
        if (remain == 0) {
            delete(getOrderDetail[tokenId]);
            delete userOrderAtPrice[to][orderDetail._price];
            _burn(tokenId);
        }
        else {
            emit OrderUpdate(tokenId, orderDetail._offer, orderDetail._remain, orderDetail._offer, remain);
            getOrderDetail[tokenId]._remain = remain;
        }
    }

    function _add(uint256 _tokenId, uint256 _offer, uint256 _remain) private {
        OrderDetail memory orderDetail = getOrderDetail[_tokenId];
        (uint256 offer, uint256 remain) = (orderDetail._offer.add(_offer), orderDetail._remain.add(_remain));
        emit OrderUpdate(_tokenId, orderDetail._offer, orderDetail._remain, offer, remain);
        getOrderDetail[_tokenId]._offer = offer;
        getOrderDetail[_tokenId]._remain = remain;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
    public
    view
    virtual
    override(AccessControlEnumerable, ERC721, ERC721Enumerable)
    returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}