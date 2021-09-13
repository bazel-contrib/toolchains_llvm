#include <array>
#include <cassert>

int main() {
    std::array<int, 5> v = { 1, 2, 3, 4, 5 };

    auto sum = 0;
    for (const auto& i : v) { sum += i; }
    assert(sum == 15);

    return 0;
}
