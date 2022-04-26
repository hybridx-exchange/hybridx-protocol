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

contract OrderNFT is
    Context,
    AccessControlEnumerable,
    ERC721Enumerable,
    ERC721Burnable,
    Ownable {

    event OrderUpdate(uint256 indexed tokenId, uint256 offer1, uint256 remain1, uint256 offer2, uint256 remain2);

    struct OrderDetail {
        uint256 _price;
        uint256 _offer;
        uint256 _remain;
        uint8 _type;
        uint8 _index;
    }

    using Counters for Counters.Counter;
    using SafeMath for uint256;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    Counters.Counter private _tokenIdTracker;
    string private _baseTokenURI = "";

    address public orderbook;
    mapping(uint => OrderDetail) public getOrderDetail;
    constructor(address _orderbook) ERC721("HybridX Order", "ORDER") {
        orderbook = _orderbook;
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(MINTER_ROLE, _orderbook);
        _tokenIdTracker.increment();
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    function mint(OrderDetail memory orderDetail, address to) public virtual {
        require(hasRole(MINTER_ROLE, _msgSender()), "ORDER: must have minter role to mint");
        getOrderDetail[_tokenIdTracker.current()] = orderDetail;
        _mint(to, _tokenIdTracker.current());
        _tokenIdTracker.increment();
    }

    function burn(uint256 tokenId) public virtual override {
        require(hasRole(MINTER_ROLE, _msgSender()), "ORDER: must have minter role to burn");
        delete(getOrderDetail[tokenId]);
        _burn(tokenId);
    }

    function add(uint256 tokenId, uint256 amount) public virtual {
        require(hasRole(MINTER_ROLE, _msgSender()), "ORDER: must have minter role to deposit");
        OrderDetail memory orderDetail = getOrderDetail[tokenId];
        require(orderDetail._price != 0, "ORDER: order must be exist");
        (uint256 offer, uint256 remain) = (orderDetail._offer.add(amount), orderDetail._remain.add(amount));

        emit OrderUpdate(tokenId, orderDetail._offer, orderDetail._remain, offer, remain);

        getOrderDetail[tokenId]._offer = offer;
        getOrderDetail[tokenId]._remain = remain;
    }

    function sub(uint256 tokenId, uint256 amount) public virtual {
        require(hasRole(MINTER_ROLE, _msgSender()), "ORDER: must have minter role to deposit");
        OrderDetail memory orderDetail = getOrderDetail[tokenId];
        require(orderDetail._price != 0, "ORDER: order must be exist");
        uint256 remain = orderDetail._remain.sub(amount);
        if (remain == 0) {
            this.burn(tokenId);
        }
        else {
            emit OrderUpdate(tokenId, orderDetail._offer, orderDetail._remain, orderDetail._offer, remain);
            getOrderDetail[tokenId]._remain = remain;
        }
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