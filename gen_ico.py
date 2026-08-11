from PIL import Image

img = Image.open("icons/Coda_logo.png").convert("RGBA")
w, h = img.size
print(f"Source: {w}x{h}")

if w < 256 or h < 256:
    img = img.resize((256, 256), Image.LANCZOS)

sizes = [(16,16),(24,24),(32,32),(48,48),(64,64),(128,128),(256,256)]
img.save("icons/app_icon.ico", format="ICO", sizes=sizes)
print("Saved icons/app_icon.ico")

ico = Image.open("icons/app_icon.ico")
print(f"ICO size: {ico.size}")
