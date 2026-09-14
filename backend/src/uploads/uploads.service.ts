import {
  BadRequestException,
  Injectable,
} from '@nestjs/common';

import { randomUUID } from 'node:crypto';

import { FirebaseService } from '../firebase/firebase.service.js';

@Injectable()
export class UploadsService {
  constructor(
    private readonly firebaseService: FirebaseService,
  ) {}

  async uploadProductImage(
    merchantId: string,
    file: Express.Multer.File,
  ) {
    return this.uploadImage(merchantId, file, 'products');
  }

  async uploadStoreImage(
    merchantId: string,
    file: Express.Multer.File,
  ) {
    return this.uploadImage(merchantId, file, 'stores');
  }

  async uploadCategoryImage(
    merchantId: string,
    file: Express.Multer.File,
  ) {
    return this.uploadImage(merchantId, file, 'categories');
  }

  async uploadKycDocument(uid: string, role: 'merchant' | 'delivery', documentType: string, file: Express.Multer.File) {
    if (!file) throw new BadRequestException('KYC document is required');
    const allowed = ['application/pdf', 'image/jpeg', 'image/png'];
    if (!allowed.includes(file.mimetype)) throw new BadRequestException('KYC documents must be PDF, JPG or PNG');
    if (file.size > 10 * 1024 * 1024) throw new BadRequestException('KYC document must be 10MB or smaller');
    const extension = file.mimetype === 'application/pdf' ? 'pdf' : file.mimetype === 'image/png' ? 'png' : 'jpg';
    const objectKey = `kyc/${role}/${uid}/${documentType}/${randomUUID()}.${extension}`;
    const storageFile = this.firebaseService.getStorage().bucket().file(objectKey);
    await storageFile.save(file.buffer, { metadata: { contentType: file.mimetype, metadata: { privateKyc: 'true', ownerUid: uid } }, resumable: false });
    return { success: true, objectKey, documentType };
  }

  async getKycSignedUrl(objectKey: string) {
    if (!objectKey.startsWith('kyc/')) throw new BadRequestException('Invalid KYC object key');
    const [url] = await this.firebaseService.getStorage().bucket().file(objectKey).getSignedUrl({ action: 'read', expires: Date.now() + 15 * 60 * 1000 });
    return { success: true, url, expiresAt: new Date(Date.now() + 15 * 60 * 1000).toISOString() };
  }

  private async uploadImage(
    merchantId: string,
    file: Express.Multer.File,
    folder: 'products' | 'stores' | 'categories',
  ) {
    if (!file) {
      throw new BadRequestException(
        'Image file is required',
      );
    }

    const allowedMimeTypes = [
      'image/jpeg',
      'image/png',
      'image/webp',
    ];

    if (!allowedMimeTypes.includes(file.mimetype)) {
      throw new BadRequestException(
        'Only JPG, PNG and WEBP images are allowed',
      );
    }

    const extension =
      file.mimetype === 'image/png'
        ? 'png'
        : file.mimetype === 'image/webp'
          ? 'webp'
          : 'jpg';

    const fileName =
      `${folder}/${merchantId}/${randomUUID()}.${extension}`;

    const bucket =
      this.firebaseService
        .getStorage()
        .bucket();

    const storageFile =
      bucket.file(fileName);

    const downloadToken = randomUUID();

    await storageFile.save(file.buffer, {
      metadata: {
        contentType: file.mimetype,
        metadata: {
          firebaseStorageDownloadTokens:
            downloadToken,
        },
      },
      resumable: false,
    });

    const encodedPath =
      encodeURIComponent(fileName);

    const imageUrl =
      `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/${encodedPath}?alt=media&token=${downloadToken}`;

    return {
      success: true,
      imageUrl,
      path: fileName,
    };
  }
}
