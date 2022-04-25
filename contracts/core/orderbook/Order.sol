// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "../../deps/access/Ownable.sol";
import "./interfaces/IOrder.sol";
import "../../deps/ERC721.sol";
import "../../deps/extensions/ERC721Enumerable.sol";
import "../../deps/extensions/ERC721Burnable.sol";
import "../../deps/access/AccessControlEnumerable.sol";
import "../../deps/utils/Context.sol";
import "../../deps/utils/Counters.sol";

contract Order is
    Context,
    AccessControlEnumerable,
    ERC721Enumerable,
    ERC721Burnable,
    IOrder,
    Ownable {

    struct OrderDetail {
        uint _price;
        uint _offer;
        uint _remain;
        uint8 _type;
        uint8 _index;
    }

    using Counters for Counters.Counter;

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
        delete(getOrderDetail[tokenId]);
        super.burn(tokenId);
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