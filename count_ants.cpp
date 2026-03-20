#include <filesystem>
#include <iostream>
#include <string>
#include <vector>

#include <opencv2/opencv.hpp>
#include <yaml-cpp/yaml.h>

struct CropConfig {
    int x;
    int y;
    int width;
    int height;
};

struct MotionFilterConfig {
    int gaussian_kernel;
    double gaussian_sigma;
    double intensity_threshold;
};

struct ColorFilterConfig {
    int color_threshold;
    int dilate_kernel;
    int dilate_iterations;
    double contour_area_max;
};

struct ContourFilterConfig {
    double area_min;
    double area_max;
};

struct BlurFilterConfig {
    double variance_threshold;
};

struct ClassifyConfig {
    int some_ants_threshold;
    int many_ants_threshold;
};

struct Config {
    CropConfig crop;
    MotionFilterConfig motion_filter;
    ColorFilterConfig color_filter;
    ContourFilterConfig contour_filter;
    BlurFilterConfig blur_filter;
    ClassifyConfig classify;
};

Config load_config(const std::filesystem::path& config_path) {
    YAML::Node root = YAML::LoadFile(config_path.string());

    Config config;
    config.crop.x = root["crop"]["x"].as<int>();
    config.crop.y = root["crop"]["y"].as<int>();
    config.crop.width = root["crop"]["width"].as<int>();
    config.crop.height = root["crop"]["height"].as<int>();

    config.motion_filter.gaussian_kernel = root["motion_filter"]["gaussian_kernel"].as<int>();
    config.motion_filter.gaussian_sigma = root["motion_filter"]["gaussian_sigma"].as<double>();
    config.motion_filter.intensity_threshold = root["motion_filter"]["intensity_threshold"].as<double>();

    config.color_filter.color_threshold = root["color_filter"]["color_threshold"].as<int>();
    config.color_filter.dilate_kernel = root["color_filter"]["dilate_kernel"].as<int>();
    config.color_filter.dilate_iterations = root["color_filter"]["dilate_iterations"].as<int>();
    config.color_filter.contour_area_max = root["color_filter"]["contour_area_max"].as<double>();

    config.contour_filter.area_min = root["contour_filter"]["area_min"].as<double>();
    config.contour_filter.area_max = root["contour_filter"]["area_max"].as<double>();

    config.blur_filter.variance_threshold = root["blur_filter"]["variance_threshold"].as<double>();

    config.classify.some_ants_threshold = root["classify"]["some_ants_threshold"].as<int>();
    config.classify.many_ants_threshold = root["classify"]["many_ants_threshold"].as<int>();

    return config;
}

cv::Mat crop_image(const std::string& file, const Config& config) {
    cv::Mat image = cv::imread(file);
    if (image.empty()) {
        throw std::runtime_error("Failed to read image: " + file);
    }

    const cv::Rect roi(config.crop.x, config.crop.y, config.crop.width, config.crop.height);
    if (roi.x < 0 || roi.y < 0 || roi.x + roi.width > image.cols || roi.y + roi.height > image.rows) {
        throw std::runtime_error("Crop ROI out of bounds for image: " + file);
    }

    cv::Mat cropped = image(roi).clone();
    cropped.convertTo(cropped, CV_32FC3);
    return cropped;
}

cv::Mat motion_filter(const cv::Mat& a, const cv::Mat& b, const Config& config) {
    int k = config.motion_filter.gaussian_kernel;
    if (k % 2 == 0) {
        k += 1;
    }

    cv::Mat a_blur;
    cv::Mat b_blur;
    cv::GaussianBlur(a, a_blur, cv::Size(k, k), config.motion_filter.gaussian_sigma);
    cv::GaussianBlur(b, b_blur, cv::Size(k, k), config.motion_filter.gaussian_sigma);

    cv::Mat abs_diff;
    cv::absdiff(a_blur, b_blur, abs_diff);

    std::vector<cv::Mat> channels;
    cv::split(abs_diff, channels);
    cv::Mat diff = channels[0].clone();
    diff = cv::max(diff, channels[1]);
    diff = cv::max(diff, channels[2]);

    double max_val = 0.0;
    cv::minMaxLoc(diff, nullptr, &max_val);
    if (max_val > config.motion_filter.intensity_threshold) {
        diff = diff * (255.0 / max_val);
    }

    diff.convertTo(diff, CV_8U);

    cv::Mat tdiff;
    double tval = cv::threshold(diff, tdiff, 0, 255, cv::THRESH_TRIANGLE | cv::THRESH_BINARY);
    double min_val = 0.0;
    cv::minMaxLoc(diff, &min_val, nullptr);
    tval = std::max(tval, min_val + 10.0);

    cv::Mat out;
    cv::threshold(diff, out, tval, 255, cv::THRESH_BINARY);
    return out;
}

cv::Mat color_filter(const cv::Mat& a, const cv::Mat& b, const Config& config) {
    cv::Mat burn;
    cv::min(a, b, burn);
    burn.convertTo(burn, CV_8UC3);

    std::vector<cv::Mat> channels;
    cv::split(burn, channels);

    cv::Mat thresh = channels[0].clone();
    thresh = cv::max(thresh, channels[1]);
    thresh = cv::max(thresh, channels[2]);

    cv::threshold(thresh, thresh, config.color_filter.color_threshold, 255, cv::THRESH_BINARY);
    cv::bitwise_not(thresh, thresh);

    int kernel_size = config.color_filter.dilate_kernel;
    cv::Mat kernel = cv::Mat::ones(kernel_size, kernel_size, CV_8U);
    cv::dilate(thresh, thresh, kernel, cv::Point(-1, -1), config.color_filter.dilate_iterations);

    std::vector<std::vector<cv::Point>> contours;
    cv::findContours(thresh, contours, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_NONE);

    std::vector<std::vector<cv::Point>> hulls;
    hulls.reserve(contours.size());
    for (const auto& contour : contours) {
        std::vector<cv::Point> hull;
        cv::convexHull(contour, hull);
        if (cv::contourArea(hull) <= config.color_filter.contour_area_max) {
            hulls.push_back(hull);
        }
    }

    cv::Mat filled = cv::Mat::zeros(thresh.size(), thresh.type());
    if (!hulls.empty()) {
        cv::fillPoly(filled, hulls, cv::Scalar(255), cv::LINE_4);
    }

    return filled;
}

int contour_filter(const cv::Mat& thresh, const cv::Mat& diff, const Config& config) {
    cv::Mat img;
    cv::bitwise_and(thresh, diff, img);

    std::vector<std::vector<cv::Point>> contours;
    cv::findContours(img, contours, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_NONE);

    int ants = 0;
    for (const auto& contour : contours) {
        double area = cv::contourArea(contour);
        if (area >= config.contour_filter.area_min && area <= config.contour_filter.area_max) {
            ants += 1;
        }
    }
    return ants;
}

bool blur_filter(const cv::Mat& image, const Config& config) {
    cv::Mat laplacian;
    cv::Laplacian(image, laplacian, CV_32F);

    cv::Scalar mean;
    cv::Scalar stddev;
    cv::meanStdDev(laplacian, mean, stddev);
    double variance = stddev[0] * stddev[0];

    return variance <= config.blur_filter.variance_threshold;
}

int classify(const std::string& file1, const std::string& file2, const Config& config) {
    cv::Mat a = crop_image(file1, config);
    cv::Mat b = crop_image(file2, config);

    if (blur_filter(a, config)) {
        return 0;
    }

    cv::Mat diff = motion_filter(a, b, config);
    cv::Mat thresh = color_filter(a, b, config);
    int ants = contour_filter(thresh, diff, config);

    if (ants < config.classify.some_ants_threshold) {
        return 1;
    }
    if (ants < config.classify.many_ants_threshold) {
        return 2;
    }
    return 3;
}

int main(int argc, char** argv) {
    if (argc != 3) {
        std::cerr << "Usage: count_ants <file1> <file2>" << std::endl;
        return 1;
    }

    try {
        const std::filesystem::path config_path = "config.yaml";
        Config config = load_config(config_path);
        int ants = classify(argv[1], argv[2], config);
        std::cout << ants << std::endl;
    } catch (const std::exception& e) {
        std::cerr << e.what() << std::endl;
        return 1;
    }

    return 0;
}