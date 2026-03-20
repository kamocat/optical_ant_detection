from sys import argv
from pathlib import Path

import cv2 as cv
import numpy as np
import yaml

CONFIG = None

def load_config():
    global CONFIG
    config_path = Path(__file__).parent / "config.yaml"
    with open(config_path, 'r') as f:
        CONFIG = yaml.safe_load(f)
    return CONFIG

def crop_image(file):
    image = cv.imread(file)
    cropx = CONFIG['crop']['x']
    wx = CONFIG['crop']['width']
    cropy = CONFIG['crop']['y']
    wy = CONFIG['crop']['height']
    return image[cropy:cropy+wy, cropx:cropx+wx].astype(np.float32)

def motion_filter(a,b):
    k = CONFIG['motion_filter']['gaussian_kernel']
    sigma = CONFIG['motion_filter']['gaussian_sigma']
    a = cv.GaussianBlur(a, (k, k), sigma)
    b = cv.GaussianBlur(b, (k, k), sigma)
    diff = np.max(np.abs(a - b), axis=2)
    if np.max(diff) > CONFIG['motion_filter']['intensity_threshold']:
        diff *= 255/np.max(diff)
    diff = diff.astype(np.uint8)
    tval, tdiff =  cv.threshold(diff, 0, 255, cv.THRESH_DRYRUN + cv.THRESH_TRIANGLE)
    tval = max(tval, np.min(diff)+10)
    _, diff = cv.threshold(diff, tval, 255, cv.THRESH_BINARY)
    return diff

def color_filter(a,b):
    burn = np.minimum(a,b).astype(np.uint8)
    thresh = np.max(burn, axis=2).astype(np.uint8)
    thresh = cv.threshold(thresh, CONFIG['color_filter']['color_threshold'], 255, cv.THRESH_BINARY)[1]
    kernel_size = CONFIG['color_filter']['dilate_kernel']
    thresh = cv.bitwise_not(thresh)
    thresh = cv.dilate(thresh, np.ones((kernel_size, kernel_size), np.uint8), iterations=CONFIG['color_filter']['dilate_iterations'])
    contours, _ = cv.findContours(thresh, cv.RETR_EXTERNAL, cv.CHAIN_APPROX_NONE)
    contours = [cv.convexHull(c) for c in contours]
    contours = [c for c in contours if cv.contourArea(c) <= CONFIG['color_filter']['contour_area_max']]
    thresh = np.zeros_like(thresh)
    cv.fillPoly(thresh, contours, 255, cv.LINE_4)
    return thresh

def contour_filter(thresh, diff):
    img = cv.bitwise_and(thresh, diff)
    contours = cv.findContours(img, cv.RETR_EXTERNAL, cv.CHAIN_APPROX_NONE)[0]
    contours = [c for c in contours if CONFIG['contour_filter']['area_min'] <= cv.contourArea(c) <= CONFIG['contour_filter']['area_max']]
    ants = len(contours)
    return ants

def blur_filter(a):
    variance = cv.Laplacian(a, cv.CV_32F).var()
    return variance <= CONFIG['blur_filter']['variance_threshold']

def classify(f1, f2):
    a = crop_image(f1)
    b = crop_image(f2)
    if blur_filter(a):
        return 0
    diff = motion_filter(a,b)
    thresh = color_filter(a,b)
    ants = contour_filter(thresh, diff)
    if ants < CONFIG['classify']['some_ants_threshold']:
        return 1
    elif ants < CONFIG['classify']['many_ants_threshold']:
        return 2
    else:
        return 3

def main():
    load_config()
    if len(argv) != 3:
        print("Usage: count_ants.py <file1> <file2>")
        return 1
    ants = classify(argv[1], argv[2])
    print(ants)
    return 0

if __name__ == "__main__":
    exit(main())