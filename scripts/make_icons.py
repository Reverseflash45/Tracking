"""Turunkan aset icon dari Icon/icon.png (logo terang di latar hitam).

Menghasilkan:
  Icon/icon_1024.png        - versi persegi 1024x1024 (iOS, web, windows)
  Icon/icon_foreground.png  - logo alpha-transparan untuk adaptive icon Android

Catatan proporsi: flutter_launcher_icons membungkus foreground dengan
`android:inset="16%"` (konten menyusut jadi ~68%). Karena itu foreground di sini
di-crop ke bounding box logo lalu diskalakan ke LOGO_SPAN, supaya setelah inset
logonya mengisi ~54% dari icon - proporsi yang wajar untuk launcher.

Butuh: pip install pillow numpy
Jalankan dari root project:  python scripts/make_icons.py
Lalu regenerate icon platform: dart run flutter_launcher_icons
"""

import numpy as np
from PIL import Image

SRC = 'Icon/icon.png'
TARGET = 1024
LOGO_SPAN = 0.79
ALPHA_THRESHOLD = 8

src = Image.open(SRC).convert('RGB')

# 1) Versi persegi penuh (frame asli, logo sudah punya padding sendiri).
square = src.resize((TARGET, TARGET), Image.LANCZOS)
square.save('Icon/icon_1024.png')
print('wrote Icon/icon_1024.png', square.size)

# 2) Cari bounding box logo, jadikan persegi di sekitar pusatnya.
arr = np.asarray(src).astype(np.int32)
ys, xs = np.nonzero(arr.max(axis=2) > ALPHA_THRESHOLD)
side = max(xs.max() - xs.min(), ys.max() - ys.min()) + 1
cx, cy = (xs.min() + xs.max()) // 2, (ys.min() + ys.max()) // 2
box = (cx - side // 2, cy - side // 2, cx - side // 2 + side, cy - side // 2 + side)
cropped = src.crop(box)
print('logo bbox', box, 'side', side)

# 3) Latar hitam berarti gambar efektif sudah "premultiplied" (hitam tidak
# berkontribusi warna), jadi alpha = channel maksimum dan warna = rgb / alpha.
carr = np.asarray(cropped).astype(np.float32)
alpha = carr.max(axis=2)
safe = np.where(alpha > 0, alpha, 1.0)
rgb = np.clip(carr / safe[..., None] * 255.0, 0, 255)
logo = Image.fromarray(np.dstack([rgb, alpha]).astype(np.uint8))

inner = int(TARGET * LOGO_SPAN)
offset = (TARGET - inner) // 2
foreground = Image.new('RGBA', (TARGET, TARGET), (0, 0, 0, 0))
foreground.paste(logo.resize((inner, inner), Image.LANCZOS), (offset, offset))
foreground.save('Icon/icon_foreground.png')
print('wrote Icon/icon_foreground.png', foreground.size, 'logo span', inner)
