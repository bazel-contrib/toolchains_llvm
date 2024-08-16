#include <string>
#include <iostream>

int main(int argc, char** argv) {
    if (argc != 2) {
        std::cout << "Not enough arguments" << std::endl;
        return 1;
    }

    std::string arg = argv[1];

#ifdef TEST_DEFINE
    if (arg != "yes") {
        std::cout << "TEST_DEFINE is defined but it was expected to be not defined" << std::endl;
        return 1;
    }
#else
    if (arg != "no") {
        std::cout << "TEST_DEFINE is not defined but it was expected to be defined" << std::endl;
        return 1;
    }
#endif
    return 0;
}