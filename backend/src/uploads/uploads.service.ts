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
      `products/${merchantId}/${randomUUID()}.${extension}`;

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