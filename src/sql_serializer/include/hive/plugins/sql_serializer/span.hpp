#pragma once
#include <iterator>
#include <array>

// TODO: Use std::span from C++20
template<typename T>
struct span
{
  template<typename Container>
  span(const Container& container) :
    begin_{&*std::begin(container)}, size_{container.size()}
  {}
  template<typename Container>
  span(Container& container) :
    begin_{&*std::begin(container)}, size_{container.size()}
  {}

  T* begin_;
  size_t size_;

  T* begin() const noexcept
  { return begin_; }

  T* end() const noexcept
  { return begin_ + size_; }

  auto size() const
  { return size_; }
};

template <class T, size_t N>
span(T (&)[N]) -> span<T>;

template <class T, size_t N>
span(std::array<T, N>&)->span<T>;

template <class T, size_t N>
span(const std::array<T, N>&)->span<const T>;

template <class Container>
span(Container&) -> span<typename Container::value_type>;

template <class Container>
span(const Container&) -> span<const typename Container::value_type>;
