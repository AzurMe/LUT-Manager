# Camera Tag Catalog

LUT Manager keeps a curated seed list of mainstream camera brands, camera models, camera categories, and common capture profiles in:

```text
lib/data/camera_tag_catalog.dart
```

The list is used to populate the collapsible Tag picker in the library sidebar. It is intentionally a seed catalog rather than a locked taxonomy: users can still add custom Tag values in metadata editing.

## Build Notes

The current catalog was researched from official manufacturer product pages and product indexes on 2026-05-23. It focuses on camera bodies that are commonly relevant to LUT workflows:

- mirrorless hybrid cameras
- cinema cameras
- medium-format cameras
- action / 360 cameras
- drone and handheld creator cameras
- compact cameras with Log or flat color workflows

## Source Pages

- Canon EOS R System: <https://www.usa.canon.com/cameras/eos-r-system>
- Sony interchangeable-lens cameras: <https://electronics.sony.com/imaging/interchangeable-lens-cameras/c/all-interchangeable-lens-cameras>
- Nikon Z mirrorless lineup: <https://imaging.nikon.com/imaging/lineup/mirrorless/index.html>
- Fujifilm X Series and GFX cameras: <https://www.fujifilm-x.com/en-us/products/cameras/>
- Panasonic LUMIX G Series: <https://shop.panasonic.com/pages/lumix-g-series-mirrorless-micro-four-thirds-cameras>
- OM SYSTEM cameras: <https://explore.omsystem.com/us/en/cameras>
- Leica cameras: <https://leica-camera.com/en-US/camera>
- Blackmagic Design products: <https://www.blackmagicdesign.com/products>
- Hasselblad 907X and CFV 100C: <https://www.hasselblad.com/v-system/907x-cfv-100c/>
- DJI handheld imaging devices: <https://www.dji.com/global/products/handheld-imaging-devices>
- GoPro official store: <https://gopro.com/en/us/>
- RED products: <https://www.red.com/products>
- ARRI cameras: <https://www.arri.com/en/camera-systems/cameras>
- Ricoh/Pentax K-3 Mark III: <https://us.ricoh-imaging.com/product/pentax-k-3-mark-iii/>
- SIGMA BF camera: <https://www.sigmaphoto.com/bf-camera>

## Maintenance

When adding new camera models:

1. Add the brand and model to `cameraBrandModels`.
2. Add any new common sensor/category wording to `cameraCategoryTags`.
3. Add new Log or flat profiles to `captureProfileTags`.
4. Run `flutter analyze` and `flutter test`.
