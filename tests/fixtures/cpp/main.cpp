#include <algorithm>
#include <string>
#include <vector>

namespace tree {

/// Doc comment one
/// Doc comment two
template <typename T>
class Tree {
public:
    explicit Tree(T root) : root_(root) {}

    void insert(
        const T &value,
        bool left
    ) {
        if (left) {
            items_.push_back(value);
        } else {
            items_.insert(items_.begin(), value);
        }
    }

    std::vector<T> sorted() const {
        auto copy = items_;
        std::sort(copy.begin(), copy.end(), [](const T &a, const T &b) {
            return a < b;
        });
        return copy;
    }

private:
    T root_;
    std::vector<T> items_;
};

struct Config {
    std::string name;
    int retries;
};

}  // namespace tree

int main() {
    tree::Tree<int> t(0);
    t.insert(1, true);
    std::vector<int> values = {
        1,
        2,
    };
    tree::Config cfg{
        "x",
        3,
    };
    try {
        t.insert(2, false);
    } catch (const std::exception &e) {
        return 1;
    }
    auto twice = [&](int x) {
        return x * 2;
    };
    return twice(cfg.retries) + static_cast<int>(values.size());
}
