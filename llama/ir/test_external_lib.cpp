// 测试 Clang++ IR 与 GCC 混合链接
#include <vector>
#include <algorithm>
#include <cmath>

// 示例 1: 内部使用 STL，接口是 C 风格
extern "C" float compute_vector_norm(const float* data, size_t len) {
    std::vector<float> vec(data, data + len);

    float sum = 0.0f;
    for (float v : vec) {
        sum += v * v;
    }
    return std::sqrt(sum);
}

// 示例 2: 排序数组
extern "C" void sort_array(int* data, size_t len) {
    std::vector<int> vec(data, data + len);
    std::sort(vec.begin(), vec.end());
    std::copy(vec.begin(), vec.end(), data);
}

// 示例 3: 查找最大值
extern "C" int find_max(const int* data, size_t len) {
    std::vector<int> vec(data, data + len);
    return *std::max_element(vec.begin(), vec.end());
}

// 示例 4: 使用模板（内部）
template<typename T>
static T compute_mean(const T* data, size_t len) {
    T sum = 0;
    for (size_t i = 0; i < len; i++) {
        sum += data[i];
    }
    return sum / static_cast<T>(len);
}

extern "C" float compute_mean_float(const float* data, size_t len) {
    return compute_mean(data, len);
}
