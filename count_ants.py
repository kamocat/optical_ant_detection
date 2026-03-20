from sys import argv

import cv2 as cv
import numpy as np

def crop_image(file):
    image = cv.imread(file)
    cropx = 600
    wx = 1150
    cropy = 600
    wy = 250
    return image[cropy:cropy+wy, cropx:cropx+wx].astype(np.float32)

def motion_filter(a,b):
    k = 3
    a = cv.GaussianBlur(a, (k, k), 0)
    b = cv.GaussianBlur(b, (k, k), 0)
    diff = np.max(np.abs(a - b), axis=2)
    if np.max(diff) > 50:
        diff *= 255/np.max(diff)
    diff = diff.astype(np.uint8)
    tval, tdiff =  cv.threshold(diff, 0, 255, cv.THRESH_DRYRUN + cv.THRESH_TRIANGLE)
    tval = max(tval, np.min(diff)+10)
    _, diff = cv.threshold(diff, tval, 255, cv.THRESH_BINARY)
    return diff

def color_filter(a,b):
    burn = np.minimum(a,b).astype(np.uint8)
    thresh = np.max(burn, axis=2).astype(np.uint8)
    thresh = cv.threshold(thresh, 70, 255, cv.THRESH_BINARY)[1]
    thresh = cv.erode(thresh, np.ones((3, 3), np.uint8), iterations=1)
    thresh = cv.bitwise_not(thresh)
    contours, _ = cv.findContours(thresh, cv.RETR_EXTERNAL, cv.CHAIN_APPROX_NONE)
    contours = [cv.convexHull(c) for c in contours]
    contours = [c for c in contours if cv.contourArea(c) <= 30]
    thresh = np.zeros_like(thresh)
    cv.fillPoly(thresh, contours, 255, cv.LINE_4)
    return thresh

def contour_filter(thresh, diff):
    img = cv.bitwise_and(thresh, diff)
    contours = cv.findContours(img, cv.RETR_EXTERNAL, cv.CHAIN_APPROX_NONE)[0]
    contours = [c for c in contours if 6 <= cv.contourArea(c) <= 30]
    ants = len(contours)
    return ants

def blur_filter(a):
    variance = cv.Laplacian(a, cv.CV_32F).var()
    return variance <= 35

def classify(f1, f2):
    a = crop_image(f1)
    b = crop_image(f2)
    if blur_filter(a):
        return 0
    diff = motion_filter(a,b)
    thresh = color_filter(a,b)
    ants = contour_filter(thresh, diff)
    if ants < 1:
        return 1
    elif ants < 4:
        return 2
    else:
        return 3

def main():
    if len(argv) != 3:
        print("Usage: count_ants.py <file1> <file2>")
        return 1
    ants = classify(argv[1], argv[2])
    print(ants)
    return 0

if __name__ == "__main__":
    exit(main())