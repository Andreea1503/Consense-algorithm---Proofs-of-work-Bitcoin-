#include <stdio.h>
#include <stdint.h>
#include "../include/utils.cuh"
#include <string.h>
#include <stdlib.h>
#include <inttypes.h>
#define THREADS_PER_BLOCK 500

__global__ void findNonce(BYTE *block_content, BYTE *difficulty, uint64_t *found_nonce, BYTE *block_hash) {
	// calculate the nonce for the current block and current thread
    uint64_t nonce = blockIdx.x * blockDim.x + threadIdx.x;
    BYTE local_hash[SHA256_HASH_SIZE];
    char nonce_string[NONCE_SIZE];
    BYTE local_block_content[BLOCK_SIZE];
	// set the maximum nonce value
	uint64_t max_nonce = MAX_NONCE;

	// copy the block content to local block content
    memcpy(local_block_content, block_content, BLOCK_SIZE);
	// calculate the length of the local block content
    int content_length = d_strlen((const char*)local_block_content);

    // verifying if the nonce was already found by another thread
    if (*found_nonce > 0) {
        return;
    }

    // verify if the nonce is greater than the maximum nonce
    if (nonce > max_nonce) {
        return;
    }

    // generate the nonce string
    intToString(nonce, nonce_string);

    // concatenating the nonce string to the local block content
    d_strcpy((char*)local_block_content + content_length, nonce_string);

    // calculate the hash of the local block content
    apply_sha256(local_block_content, d_strlen((const char*)local_block_content), local_hash, 1);

    // compare the hash with the given difficulty
    if (compare_hashes(local_hash, difficulty) <= 0) {
        // if the hash is less than the difficulty, then the nonce is found
		// and then the local block hash and nonce are copied to the global block hash and nonce
		// using an atomic operation
		if(atomicExch((unsigned long long int*)found_nonce, nonce) == 0) {
			*found_nonce = nonce;
			memcpy(block_hash, local_hash, SHA256_HASH_SIZE);
		}
    }
}


int main(int argc, char **argv) {
    // Declarations
    BYTE block_content[BLOCK_SIZE];
    BYTE block_hash[SHA256_HASH_SIZE] = {0};
    uint64_t nonce = 0;
    size_t current_length;

    // Compute the top hash of transactions
    BYTE hashed_tx1[SHA256_HASH_SIZE], hashed_tx2[SHA256_HASH_SIZE], hashed_tx3[SHA256_HASH_SIZE], hashed_tx4[SHA256_HASH_SIZE],
         tx12[SHA256_HASH_SIZE * 2], tx34[SHA256_HASH_SIZE * 2], hashed_tx12[SHA256_HASH_SIZE], hashed_tx34[SHA256_HASH_SIZE],
         tx1234[SHA256_HASH_SIZE * 2], top_hash[SHA256_HASH_SIZE];

    apply_sha256(tx1, strlen((const char*)tx1), hashed_tx1, 1);
    apply_sha256(tx2, strlen((const char*)tx2), hashed_tx2, 1);
    apply_sha256(tx3, strlen((const char*)tx3), hashed_tx3, 1);
    apply_sha256(tx4, strlen((const char*)tx4), hashed_tx4, 1);

    strcpy((char *)tx12, (const char *)hashed_tx1);
    strcat((char *)tx12, (const char *)hashed_tx2);
    apply_sha256(tx12, strlen((const char*)tx12), hashed_tx12, 1);

    strcpy((char *)tx34, (const char *)hashed_tx3);
    strcat((char *)tx34, (const char *)hashed_tx4);
    apply_sha256(tx34, strlen((const char*)tx34), hashed_tx34, 1);

    strcpy((char *)tx1234, (const char *)hashed_tx12);
    strcat((char *)tx1234, (const char *)hashed_tx34);
    apply_sha256(tx1234, strlen((const char*)tx1234), top_hash, 1);

    // Prepare the initial content of the block by combining previous block hash and top hash
    strcpy((char *)block_content, (const char *)prev_block_hash);
    strcat((char *)block_content, (const char *)top_hash);
    current_length = strlen((char*) block_content);
    printf("Block content without nonce: %s\n", block_content);

    // Device memory for kernel
    BYTE *d_block_content, *d_difficulty, *d_found_block_hash;
    uint64_t *d_found_nonce;
    cudaMalloc(&d_block_content, BLOCK_SIZE);
    cudaMalloc(&d_difficulty, SHA256_HASH_SIZE);
    cudaMalloc(&d_found_nonce, sizeof(uint64_t));
    cudaMalloc(&d_found_block_hash, SHA256_HASH_SIZE);

    // Copy data to device
    cudaMemcpy(d_block_content, block_content, current_length + 1, cudaMemcpyHostToDevice);
    cudaMemcpy(d_difficulty, difficulty_5_zeros, SHA256_HASH_SIZE, cudaMemcpyHostToDevice);
    cudaMemcpy(d_found_block_hash, block_hash, current_length + 1, cudaMemcpyHostToDevice);

    // Timing setup
    cudaEvent_t start, stop;
    startTiming(&start, &stop);

    // Launch kernel
    findNonce<<<MAX_NONCE/THREADS_PER_BLOCK, THREADS_PER_BLOCK>>>(d_block_content, d_difficulty, d_found_nonce, d_found_block_hash);

    cudaDeviceSynchronize();
    float seconds = stopTiming(&start, &stop);

    // Copy back the nonce and block hash
    cudaMemcpy(&nonce, d_found_nonce, sizeof(uint64_t), cudaMemcpyDeviceToHost);
    cudaMemcpy(block_hash, d_found_block_hash, SHA256_HASH_SIZE, cudaMemcpyDeviceToHost);

    // Print the result
    printResult(block_hash, nonce, seconds);

    // Free device memory
    cudaFree(d_block_content);
    cudaFree(d_difficulty);
    cudaFree(d_found_nonce);
    cudaFree(d_found_block_hash);

    return 0;
}
