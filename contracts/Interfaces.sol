//SPDX-License-Identifier: MIT
//  ___   ___      ______       __
// /__/\ /__/\    /_____/\     /_/\
// \::\ \\  \ \   \:::_ \ \    \:\ \
//  \::\/_\ .\ \   \:\ \ \ \    \:\ \
//   \:: ___::\ \   \:\ \ \ \    \:\ \____
//    \: \ \\::\ \   \:\_\ \ \    \:\/___/\
//     \__\/ \::\/    \_____\/     \_____\/

pragma solidity ^0.8.4;

/// @dev The interface for the SURF ERC-20 Contract.
interface SURF {
    function balanceOf(address) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function allowance(address owner, address spender)
        external
        returns (uint256);

    function transfer(address recipient, uint256 amount)
        external
        returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    function transferFee() external returns (uint256);
}

/// @dev The interface for the Ribbits contract (ribbits.xyz)
interface Ribbits {
    function approve(address _approved, uint256 _tokenId) external;

    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _tokenId
    ) external;

    function ownerOf(uint256 _tokenId) external view returns (address);

    function setApprovalForAll(address _operator, bool _approved) external;
}

/// @dev The interface for the wrapped ribbits contract
interface wRBT {
    function approve(address _spender, uint256 _tokens) external returns (bool);

    function transferFrom(
        address _from,
        address _to,
        uint256 _tokens
    ) external returns (bool);

    function transfer(address _to, uint256 _tokens) external returns (bool);

    function balanceOf(address _user) external view returns (uint256);

    function allowance(address _user, address _spender)
        external
        view
        returns (uint256);

    function wrap(uint256[] calldata _tokenIds) external;
}

/// @dev The ERC721 Receiver interface
interface IERC721Receiver {
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}
