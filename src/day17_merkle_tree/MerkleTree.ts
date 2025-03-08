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

//root:0xae910484c4fff9a5ac816ae497c219ab73f7bb85fd54cc2414440221b308b79d
//proof:0x64767c6bd9dce402a905bfdb430feb7d9f40eacb4722e23aa1ed58f9e759097f
