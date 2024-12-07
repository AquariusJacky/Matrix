#ifndef MATRIX_H
#define MATRIX_H

#include <stdlib.h>

#include <iostream>

namespace CUDA {
class Matrix;  // class forward declaration
}

class Matrix {
 private:
  size_t m_;
  size_t n_;
  float* data_;  // Stores the actual data in row-major order
  size_t calculate_index(const size_t& x, const size_t& y) const;

 public:
  friend class CUDA::Matrix;

  Matrix();
  Matrix(const size_t& m);
  Matrix(const size_t& m, const size_t& n);
  Matrix(const Matrix& matB);
  ~Matrix();

  size_t m() const { return m_; }
  size_t n() const { return n_; }
  size_t size() const { return m_ * n_; }

  float& operator()(const size_t& x, const size_t& y);
  const float& operator()(const size_t& x, const size_t& y) const;

  Matrix& operator=(const Matrix& matB);
  Matrix& operator+=(const Matrix& matB);
  Matrix& operator-=(const Matrix& matB);
  Matrix& operator*=(const float& scale);
  Matrix operator+(const Matrix& matB) const;
  Matrix operator-(const Matrix& matB) const;
  Matrix operator*(const float& scale) const;
  Matrix& copy(const Matrix& matB) { return (*this) = matB; }

  Matrix& reshape(const size_t& m);
  Matrix& reshape(const size_t& m, const size_t& n);
  Matrix& resize(const size_t& m);
  Matrix& resize(const size_t& m, const size_t& n);

  Matrix& ones();
  Matrix& ones(const size_t& m);
  Matrix& ones(const size_t& m, const size_t& n);
  Matrix& zeros();
  Matrix& zeros(const size_t& m);
  Matrix& zeros(const size_t& m, const size_t& n);

  Matrix& arange(const float& end);
  Matrix& arange(const float& start, const float& end);
  Matrix& arange(const float& start, const float& end, const float& step);

  Matrix& fill(const float& val);
  Matrix& I(const size_t& m);
  Matrix& T();
  Matrix& identity(const size_t& m) { return (*this).I(m); }
  Matrix& eye(const size_t& m) { return (*this).I(m); }
  Matrix& transpose() { return (*this).T(); }
  Matrix& abs();                            // Absolute
  Matrix& fabs() { return (*this).abs(); }  // Floating point absolute
  // Only works with square matrix, matrix self dot
  Matrix& power(const float& power);
  float sum();

  Matrix& dot(const Matrix& matB);
  Matrix& convolution(const Matrix& mask);
};

std::ostream& operator<<(std::ostream&, const Matrix&);

#endif