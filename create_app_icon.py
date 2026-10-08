import os
import subprocess
import math

# We can draw the icon using CoreGraphics/PyObjC or PIL if available, or generate a 1024x1024 PNG with Python
try:
    from PIL import Image, ImageDraw
    has_pil = True
except ImportError:
    has_pil = False

print(f"PIL available: {has_pil}")
