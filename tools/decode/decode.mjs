import { NodeIO } from '@gltf-transform/core';
import { KHRDracoMeshCompression, EXTTextureWebP } from '@gltf-transform/extensions';
import draco3d from 'draco3dgltf';
import sharp from 'sharp';

const [src, dst] = process.argv.slice(2);
const io = new NodeIO()
  .registerExtensions([KHRDracoMeshCompression, EXTTextureWebP])
  .registerDependencies({ 'draco3d.decoder': await draco3d.createDecoderModule() });
const doc = await io.read(src);
// Convert WebP textures to PNG (Godot-safe), Draco geometry is decoded on read and written plain.
for (const tex of doc.getRoot().listTextures()) {
  if (tex.getMimeType() === 'image/webp') {
    const img = tex.getImage();
    const png = await sharp(Buffer.from(img)).png().toBuffer();
    tex.setImage(new Uint8Array(png));
    tex.setMimeType('image/png');
  }
}
for (const mesh of doc.getRoot().listMeshes()) {
  for (const prim of mesh.listPrimitives()) {
    const ext = prim.getExtension('KHR_draco_mesh_compression');
    if (ext) ext.dispose();
  }
}
for (const tex of doc.getRoot().listTextures()) {
  const ext = tex.getExtension('EXT_texture_webp');
  if (ext) ext.dispose();
}
const outIO = new NodeIO().registerExtensions([EXTTextureWebP]);
for (const mat of doc.getRoot().listMaterials()) {
  const infos = [mat.getBaseColorTextureInfo(), mat.getNormalTextureInfo(), mat.getMetallicRoughnessTextureInfo(), mat.getEmissiveTextureInfo(), mat.getOcclusionTextureInfo()];
  for (const info of infos) {
    const ext = info?.getExtension('EXT_texture_webp');
    if (ext) ext.dispose();
  }
}
await outIO.write(dst, doc);
const anims = doc.getRoot().listAnimations().map(a => a.getName());
console.log('decoded ->', dst, 'animations:', anims.join(', '));
