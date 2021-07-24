//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

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
}

interface Ribbits {
    function approve(address _approved, uint256 _tokenId) external;

    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _tokenId
    ) external;

    function ownerOf(uint256 _tokenId) external view returns (address);
}

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
}