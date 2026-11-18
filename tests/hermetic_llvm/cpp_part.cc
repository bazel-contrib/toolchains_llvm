#include <stdexcept>
#include <string>
#include <vector>

int cpp_answer() {
  const std::vector<std::string> words = {"hermetic", "LLVM"};
  try {
    throw std::runtime_error(words.at(0));
  } catch (const std::exception &e) {
    return std::string(e.what()) == "hermetic" ? 42 : 0;
  }
}
