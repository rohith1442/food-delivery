import { BadRequestException, Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { mkdir, writeFile } from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';

@Injectable()
export class KycStorageService {
  private readonly root: string;
  constructor(private readonly config: ConfigService) { this.root = this.config.get<string>('KYC_UPLOAD_DIR') ?? path.join(process.cwd(), 'private-kyc'); }
  async upload(input: { uid: string; role: 'MERCHANT' | 'DELIVERY'; type: string; file: Express.Multer.File }) {
    const allowedTypes = input.role === 'MERCHANT' ? ['PAN', 'GST', 'FSSAI', 'BANK_PROOF', 'BUSINESS_PROOF', 'TRADE_LICENSE'] : ['PROFILE_PHOTO', 'IDENTITY_PROOF', 'PAN', 'DRIVING_LICENCE', 'RC', 'INSURANCE', 'BANK_PROOF'];
    if (!allowedTypes.includes(input.type.toUpperCase())) throw new BadRequestException('Unsupported document type');
    const allowed = new Set(['image/jpeg', 'image/png', 'application/pdf']);
    if (!input.file || !allowed.has(input.file.mimetype)) throw new BadRequestException('Only JPG, PNG and PDF files are allowed');
    if (input.file.size > 5 * 1024 * 1024) throw new BadRequestException('File size must not exceed 5 MB');
    const extension = this.extensionForMime(input.file.mimetype);
    const filename = `${crypto.randomUUID()}${extension}`;
    const folder = path.join(this.root, input.role.toLowerCase(), input.uid, input.type.toLowerCase());
    await mkdir(folder, { recursive: true });
    await writeFile(path.join(folder, filename), input.file.buffer);
    return { objectKey: [input.role.toLowerCase(), input.uid, input.type.toLowerCase(), filename].join('/'), originalName: input.file.originalname, mimeType: input.file.mimetype, size: input.file.size };
  }
  getPrivatePath(objectKey: string) {
    const normalized = objectKey.replace(/\\/g, '/');
    if (!normalized || normalized.startsWith('/') || normalized.split('/').includes('..')) throw new BadRequestException('Invalid private document key');
    return path.join(this.root, normalized);
  }
  private extensionForMime(mime: string) { return mime === 'image/jpeg' ? '.jpg' : mime === 'image/png' ? '.png' : '.pdf'; }
}
