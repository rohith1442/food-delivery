import { BadRequestException } from '@nestjs/common';

export function assertOwnedFirebaseImageUrl(
  imageUrl: string,
  bucketName: string,
  folder: 'products' | 'stores' | 'categories',
  merchantId: string,
): void {
  let parsedUrl: URL;

  try {
    parsedUrl = new URL(imageUrl);
  } catch {
    throw new BadRequestException('Invalid image URL');
  }

  if (
    parsedUrl.protocol !== 'https:' ||
    parsedUrl.hostname !== 'firebasestorage.googleapis.com'
  ) {
    throw new BadRequestException(
      'Invalid Firebase Storage image URL',
    );
  }

  const match = parsedUrl.pathname.match(
    /^\/v0\/b\/([^/]+)\/o\/(.+)$/,
  );

  if (!match) {
    throw new BadRequestException(
      'Invalid Firebase Storage image path',
    );
  }

  const urlBucket = decodeURIComponent(match[1]);
  const objectPath = decodeURIComponent(match[2]);

  if (urlBucket !== bucketName) {
    throw new BadRequestException(
      'Image does not belong to this application',
    );
  }

  if (!objectPath.startsWith(`${folder}/${merchantId}/`)) {
    throw new BadRequestException(
      'Image does not belong to this merchant',
    );
  }
}
