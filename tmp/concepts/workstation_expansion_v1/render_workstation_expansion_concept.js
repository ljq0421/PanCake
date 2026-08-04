const fs = require('fs');
const path = require('path');
const sharp = require('sharp');

const conceptDir = __dirname;
const basePath = path.resolve(conceptDir, '..', '..', 'validation', 'p1_order_latest.png');
const overlayPath = path.join(conceptDir, 'workstation_expansion_overlay.svg');
const outputPath = path.join(conceptDir, 'workstation_expansion_concept_v3_1920x1080.png');

async function main() {
  const metadata = await sharp(basePath).metadata();
  if (metadata.width !== 1920 || metadata.height !== 1080) {
    throw new Error(`Expected 1920x1080 source, got ${metadata.width}x${metadata.height}`);
  }

  const overlay = fs.readFileSync(overlayPath);
  await sharp(basePath)
    .composite([{ input: overlay, left: 0, top: 0 }])
    .png({ compressionLevel: 9, adaptiveFiltering: true })
    .toFile(outputPath);

  const outputMetadata = await sharp(outputPath).metadata();
  if (outputMetadata.width !== 1920 || outputMetadata.height !== 1080) {
    throw new Error(`Unexpected output size ${outputMetadata.width}x${outputMetadata.height}`);
  }

  process.stdout.write(`${outputPath}\n${outputMetadata.width}x${outputMetadata.height}\n`);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
