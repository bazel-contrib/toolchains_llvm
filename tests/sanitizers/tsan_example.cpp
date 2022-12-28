#include <thread>

auto main() -> int
{
  auto i = int{};
  const auto inc = [&i] { ++i; };

  auto t1 = std::thread{inc};
  auto t2 = std::thread{inc};
  t1.join();
  t2.join();

  return i;
}
