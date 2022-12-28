#include <iostream>
#include <string>

auto main() -> int
{
    const auto f = [] () -> const auto& {
        return std::string{"hello, world!"};
    };
    std::cout << f() << "\n";
}
