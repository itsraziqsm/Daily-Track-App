"""Membangkitkan aset brand GroU dari logo sumber (500x500, latar putih).

Pemakaian: python3 tool/brand_assets.py assets/branding/grou_source.png assets/branding
Butuh Pillow, numpy, dan scipy.
"""
import sys
import numpy as np
from PIL import Image
from scipy import ndimage

src, out = sys.argv[1], sys.argv[2]
im = np.asarray(Image.open(src).convert('RGB')).astype(float)
h, w, _ = im.shape

# Latar = area hampir putih yang tersambung ke tepi gambar. Isian putih di
# dalam garis (wajah, halaman buku) tidak tersambung, jadi tetap utuh.
whiteish = (im.min(2) > 235)
lab, _ = ndimage.label(whiteish)
edge = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
bg = np.isin(lab, list(edge))
band = ndimage.binary_dilation(bg, iterations=3) & ~bg

# Color-to-alpha terhadap putih untuk tepi anti-alias, supaya tidak ada
# lingkaran putih saat ditaruh di latar gelap.
rgba = np.zeros((h, w, 4))
rgba[..., :3] = im
rgba[..., 3] = 255
a = (255 - im).max(2) / 255.0
a_b = np.clip(a[band], 1e-3, 1)
rgba[band, :3] = np.clip((im[band] - 255 * (1 - a_b)[:, None]) / a_b[:, None], 0, 255)
rgba[band, 3] = a[band] * 255
rgba[bg, 3] = 0

def save(arr, box, size, path, pad=0.0, bgcolor=None, canvas=None):
    x0, y0, x1, y1 = box
    crop = Image.fromarray(arr[y0:y1, x0:x1].astype(np.uint8), 'RGBA')
    canvas = canvas or size
    inner = int(canvas * (1 - 2 * pad))
    scale = inner / max(crop.size)
    crop = crop.resize((round(crop.size[0] * scale), round(crop.size[1] * scale)), Image.LANCZOS)
    base = Image.new('RGBA', (canvas, canvas), bgcolor or (0, 0, 0, 0))
    base.alpha_composite(crop, ((canvas - crop.size[0]) // 2, (canvas - crop.size[1]) // 2))
    base.save(path)

# Versi gelap: hanya tulisan "GroU" yang diganti tinta terang palet gelap.
# Garis hitam ilustrasi dibiarkan; isiannya terang, jadi tetap terbaca.
dark = rgba.copy()
lum = im @ [0.299, 0.587, 0.114]
sat = im.max(2) - im.min(2)
t = np.clip((170 - lum) / 120, 0, 1) * (sat < 60)
t[:312] = 0
ink = np.array([243, 237, 227])
dark[..., :3] = dark[..., :3] * (1 - t[..., None]) + ink * t[..., None]

ys, xs = np.where(rgba[..., 3] > 10)
full = (xs.min() - 4, ys.min() - 4, xs.max() + 5, ys.max() + 5)
illus = (xs.min() - 4, ys.min() - 4, xs.max() + 5, 310)

# Logo lengkap untuk layar pembuka (dianggap @4x oleh flutter_native_splash).
save(rgba, full, 0, f'{out}/logo.png', canvas=1000, pad=0.12)
save(dark, full, 0, f'{out}/logo_dark.png', canvas=1000, pad=0.12)
# Ikon: ilustrasi saja; huruf "GroU" tak terbaca di ukuran ikon.
save(rgba, illus, 0, f'{out}/icon.png', canvas=1024, pad=0.12, bgcolor=(255, 251, 240, 255))
# Foreground ikon adaptif Android. flutter_launcher_icons sudah menyisipkan
# inset 16% di tiap sisi; padding ini menjaga sudut ilustrasi di dalam
# masker lingkaran.
save(rgba, illus, 0, f'{out}/icon_foreground.png', canvas=1024, pad=0.13)
# Splash Android 12+: ikon di tengah lingkaran, isi di dalam 2/3 kanvas.
save(rgba, illus, 0, f'{out}/splash_android12.png', canvas=1152, pad=0.2)
