#include <math.h>

#include <iostream>

#include "Matrix_CUDA.cuh"

#define BLOCK_SIZE 16

namespace CUDA {

Matrix::Matrix(const ::Matrix& cpu_mat) : m_(cpu_mat.m_), n_(cpu_mat.n_) {
  allocateDeviceMemory();

  // Copy data from CPU to GPU
  cudaError_t status = cudaMemcpy(
      d_data, cpu_mat.data_, m_ * n_ * sizeof(float), cudaMemcpyHostToDevice);

  if (status != cudaSuccess) {
    freeDeviceMemory();
    throw std::runtime_error("Failed to copy data to GPU");
  }
}

Matrix::Matrix(const size_t m, const size_t n) : m_(m), n_(n) {
  allocateDeviceMemory();
}

Matrix::Matrix(const Matrix& matB) : m_(matB.m_), n_(matB.n_) {
  allocateDeviceMemory();

  // Copy data from GPU to GPU
  cudaError_t status = cudaMemcpy(d_data, matB.d_data, m_ * n_ * sizeof(float),
                                  cudaMemcpyDeviceToDevice);

  if (status != cudaSuccess) {
    freeDeviceMemory();
    throw std::runtime_error("Failed to copy data to GPU");
  }
}

Matrix::~Matrix() {
  m_ = 0;
  n_ = 0;
  freeDeviceMemory();
}

void Matrix::allocateDeviceMemory() {
  if (m_ * n_ > 0) {
    cudaError_t status = cudaMalloc(&d_data, m_ * n_ * sizeof(float));

    if (status != cudaSuccess) {
      throw std::runtime_error("Failed to allocate GPU memory");
    }
  }
}

void Matrix::freeDeviceMemory() {
  if (d_data) {
    cudaFree(d_data);
    d_data = nullptr;
  }
}

void Matrix::toCPU(::Matrix& cpu_mat) {
  // cpu_mat = ::Matrix(m_, n_);

  cudaError_t status = cudaMemcpy(
      cpu_mat.data_, d_data, m_ * n_ * sizeof(float), cudaMemcpyDeviceToHost);

  if (status != cudaSuccess) {
    throw std::runtime_error("Failed to copy data back to CPU");
  }
}

Matrix& Matrix::operator=(const Matrix& matB) {
  freeDeviceMemory();

  m_ = matB.m_;
  n_ = matB.n_;

  allocateDeviceMemory();

  // Copy data from CPU to GPU
  cudaError_t status = cudaMemcpy(d_data, matB.d_data, m_ * n_ * sizeof(float),
                                  cudaMemcpyDeviceToDevice);

  if (status != cudaSuccess) {
    freeDeviceMemory();
    throw std::runtime_error("Failed to copy data to GPU");
  }

  return (*this);
}

// Example CUDA kernel for matrix multiplication
__global__ void matrixFillKernel(float* A, const float& val, size_t m,
                                 size_t n) {
  size_t row = blockIdx.x * blockDim.x + threadIdx.x;
  size_t col = blockIdx.y * blockDim.y + threadIdx.y;

  if (row < m && col < n) {
    A[row * n + col] = val;
  }
  __syncthreads();
}

void Matrix::fill(const float& val) {
  size_t m = m_, n = n_;

  // Set up grid and block dimensions
  dim3 blockDim(BLOCK_SIZE, BLOCK_SIZE);
  dim3 gridDim((m + blockDim.x - 1) / blockDim.x,
               (n + blockDim.y - 1) / blockDim.y);

  // Launch kernel
  matrixFillKernel<<<gridDim, blockDim>>>(d_data, val, m, n);

  // Check for errors
  cudaError_t status = cudaGetLastError();
  if (status != cudaSuccess) {
    throw std::runtime_error("Kernel launch failed");
  }

  // Synchronize
  cudaDeviceSynchronize();
}

// Example CUDA kernel for matrix multiplication
__global__ void matrixAddKernel(const float* A, const float* B, float* C,
                                size_t m, size_t n) {
  size_t row = blockIdx.x * blockDim.x + threadIdx.x;
  size_t col = blockIdx.y * blockDim.y + threadIdx.y;

  if (row < m && col < n) {
    C[row * n + col] = A[row * n + col] + B[row * n + col];
  }
  __syncthreads();
}

Matrix& Matrix::add(const Matrix& matB) {
  size_t m = m_, n = n_;

  if (matB.m_ != m || matB.n_ != n) {
    throw std::logic_error("Size of A does not match size of B");
  }

  // Set up grid and block dimensions
  dim3 blockDim(BLOCK_SIZE, BLOCK_SIZE);
  dim3 gridDim((m + blockDim.x - 1) / blockDim.x,
               (n + blockDim.y - 1) / blockDim.y);

  Matrix result(m, n);

  // Launch kernel
  matrixAddKernel<<<gridDim, blockDim>>>(d_data, matB.d_data, result.d_data, m,
                                         n);

  // Check for errors
  cudaError_t status = cudaGetLastError();
  if (status != cudaSuccess) {
    throw std::runtime_error("Kernel launch failed");
  }

  // Synchronize
  cudaDeviceSynchronize();

  return (*this) = result;
}

// Example CUDA kernel for matrix multiplication
__global__ void matrixDotKernel(const float* A, const float* B, float* C,
                                size_t m, size_t k, size_t n) {
  size_t row = blockIdx.x * blockDim.x + threadIdx.x;
  size_t col = blockIdx.y * blockDim.y + threadIdx.y;

  if (row < m && col < n) {
    float sum = 0.0f;
    for (size_t i = 0; i < k; i++) {
      sum += A[row * k + i] * B[k * n + col];
    }
    C[row * n + col] = sum;
  }
  __syncthreads();
}

Matrix Matrix::dot(const Matrix& matB) {
  size_t m = m_, k = n_, n = matB.n_;

  if (matB.m_ != k) {
    throw std::logic_error("Col # of A doesn't match Row # of B");
  }

  Matrix result(m, n);

  // Set up grid and block dimensions
  dim3 blockDim(BLOCK_SIZE, BLOCK_SIZE);
  dim3 gridDim((m_ + blockDim.x - 1) / (blockDim.x * 1.0),
               (n_ + blockDim.y - 1) / (blockDim.y * 1.0));

  // Launch kernel
  matrixDotKernel<<<gridDim, blockDim>>>(d_data, matB.d_data, result.d_data, m,
                                         k, n);

  // Check for errors
  cudaError_t status = cudaGetLastError();
  if (status != cudaSuccess) {
    throw std::runtime_error("Kernel launch failed");
  }

  // Synchronize
  cudaDeviceSynchronize();

  return result;
}

}  // namespace CUDA