import { toHex, encodePacked, keccak256 } from 'viem';
import { MerkleTree } from "merkletreejs";

const users = [
    { address: "0xD08c8e6d78a1f64B1796d6DC3137B19665cb6F1F" },
    { address: "0xb7D15753D3F76e7C892B63db6b4729f700C01298" },
    { address: "0xf69Ca530Cd4849e3d1329FBEC06787a96a3f9A68" },
    { address: "0xa8532aAa27E9f7c3a96d754674c99F1E2f824800" },
    { address: "0x3726034d259B1BbcC2b2EB0fbFF43C213705366b" },
];

// equal to MerkleDistributor.sol #keccak256(abi.encodePacked(account, amount));
const elements = users.map((x) =>
    keccak256(encodePacked(["address"], [x.address as `0x${string}`]))
);

// console.log(elements)

const merkleTree = new MerkleTree(elements, keccak256, { sort: true });

const root = merkleTree.getHexRoot();
console.log("root:" + root);


const leaf = elements[4];
const proof = merkleTree.getHexProof(leaf);
console.log("proof:" +proof);

//root:0x0bd1abfbca5006a9c51950a9cf02bdfdcfa8a5cfc0c91870360f4f171618fa1d
//proof:0x00f369b03139ffa987d43ef2453e4b14a9a184bc669bd087e69c25c51332c32f,0xafe8c6eb446c5e2ae4728675ecc904b911ba9edaff8f928bbe51a29dd4ce1e05,0xe532bea76eb3f6c701b02dbfdcbc77fc6d89a3ed2c4a30bd962fbdea284716a2
