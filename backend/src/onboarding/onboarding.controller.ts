import { BadRequestException, Body, Controller, Get, Param, Post, Put, Query, Req, Res, UploadedFile, UseGuards, UseInterceptors } from '@nestjs/common';
import type { Response } from 'express';
import { FileInterceptor } from '@nestjs/platform-express';
import { memoryStorage } from 'multer';
import { AuthGuard } from '../auth/auth.guard.js';
import { Roles } from '../auth/roles.decorator.js';
import { RolesGuard } from '../auth/roles.guard.js';
import { OnboardingService } from './onboarding.service.js';
import { KycStorageService } from '../kyc/kyc-storage.service.js';

@Controller()
@UseGuards(AuthGuard, RolesGuard)
export class OnboardingController {
  constructor(private readonly service: OnboardingService, private readonly kycStorage: KycStorageService) {}
  @Get('merchant/onboarding') @Roles('MERCHANT') getMerchant(@Req() req: any) { return this.service.get(req.user.uid, 'MERCHANT'); }
  @Put('merchant/onboarding') @Roles('MERCHANT') updateMerchant(@Req() req: any, @Body() body: Record<string, unknown>) { return this.service.update(req.user.uid, 'MERCHANT', body); }
  @Post('merchant/onboarding/submit') @Roles('MERCHANT') submitMerchant(@Req() req: any) { return this.service.submit(req.user.uid, 'MERCHANT'); }
  @Post('merchant/onboarding/documents') @Roles('MERCHANT') @UseInterceptors(FileInterceptor('file', { storage: memoryStorage(), limits: { fileSize: 5 * 1024 * 1024 } })) async documentMerchant(@Req() req: any, @UploadedFile() file: Express.Multer.File, @Body('type') type: string) { if (!file) throw new BadRequestException('File is required'); const uploaded = await this.kycStorage.upload({ uid: req.user.uid, role: 'MERCHANT', type: type?.toUpperCase(), file }); try { return await this.service.addDocument(req.user.uid, 'MERCHANT', { type, ...uploaded }); } catch (error) { await this.kycStorage.delete(uploaded.objectKey); throw error; } }
  @Get('delivery/onboarding') @Roles('DELIVERY') getDelivery(@Req() req: any) { return this.service.get(req.user.uid, 'DELIVERY'); }
  @Put('delivery/onboarding') @Roles('DELIVERY') updateDelivery(@Req() req: any, @Body() body: Record<string, unknown>) { return this.service.update(req.user.uid, 'DELIVERY', body); }
  @Post('delivery/onboarding/submit') @Roles('DELIVERY') submitDelivery(@Req() req: any) { return this.service.submit(req.user.uid, 'DELIVERY'); }
  @Post('delivery/onboarding/documents') @Roles('DELIVERY') @UseInterceptors(FileInterceptor('file', { storage: memoryStorage(), limits: { fileSize: 5 * 1024 * 1024 } })) async documentDelivery(@Req() req: any, @UploadedFile() file: Express.Multer.File, @Body('type') type: string) { if (!file) throw new BadRequestException('File is required'); const uploaded = await this.kycStorage.upload({ uid: req.user.uid, role: 'DELIVERY', type: type?.toUpperCase(), file }); try { return await this.service.addDocument(req.user.uid, 'DELIVERY', { type, ...uploaded }); } catch (error) { await this.kycStorage.delete(uploaded.objectKey); throw error; } }
  @Get('admin/merchant-onboarding') @Roles('ADMIN') listMerchants() { return this.service.list('MERCHANT'); }
  @Get('admin/merchant-onboarding/:uid') @Roles('ADMIN') getMerchantAdmin(@Param('uid') uid: string) { return this.service.getAdmin(uid, 'MERCHANT'); }
  @Get('admin/merchant-onboarding/:uid/documents') @Roles('ADMIN') merchantDocuments(@Param('uid') uid: string) { return this.service.getDocuments(uid, 'MERCHANT'); }
  @Post('admin/merchant-onboarding/:uid/verify') @Roles('ADMIN') verifyMerchant(@Param('uid') uid: string) { return this.service.verify(uid, 'MERCHANT'); }
  @Post('admin/merchant-onboarding/:uid/reject') @Roles('ADMIN') rejectMerchant(@Param('uid') uid: string, @Body('reason') reason?: string) { return this.service.reject(uid, 'MERCHANT', reason); }
  @Post('admin/merchant-onboarding/:uid/documents/:type/verify') @Roles('ADMIN') verifyMerchantDocument(@Param('uid') uid: string, @Param('type') type: string) { return this.service.setDocumentStatus(uid, 'MERCHANT', type, 'VERIFIED'); }
  @Post('admin/merchant-onboarding/:uid/documents/:type/reject') @Roles('ADMIN') rejectMerchantDocument(@Param('uid') uid: string, @Param('type') type: string) { return this.service.setDocumentStatus(uid, 'MERCHANT', type, 'REJECTED'); }
  @Post('admin/merchant-onboarding/:uid/create-linked-account') @Roles('ADMIN') linkMerchant(@Param('uid') uid: string) { return this.service.createLinkedAccount(uid); }
  @Post('admin/merchant-onboarding/:uid/activate-settlement') @Roles('ADMIN') activateSettlement(@Param('uid') uid: string) { return this.service.activateMerchantSettlement(uid); }
  @Post('admin/delivery-onboarding/:uid/setup-payout') @Roles('ADMIN') setupPayout(@Param('uid') uid: string) { return this.service.setupDeliveryPayout(uid); }
  @Post('admin/delivery-onboarding/:uid/activate-payout') @Roles('ADMIN') activatePayout(@Param('uid') uid: string) { return this.service.activateDeliveryPayout(uid); }
  @Get('admin/delivery-onboarding') @Roles('ADMIN') listDelivery() { return this.service.list('DELIVERY'); }
  @Get('admin/delivery-onboarding/:uid') @Roles('ADMIN') getDeliveryAdmin(@Param('uid') uid: string) { return this.service.getAdmin(uid, 'DELIVERY'); }
  @Get('admin/delivery-onboarding/:uid/documents') @Roles('ADMIN') deliveryDocuments(@Param('uid') uid: string) { return this.service.getDocuments(uid, 'DELIVERY'); }
  @Get('admin/kyc/document') @Roles('ADMIN') async getDocument(@Query('objectKey') objectKey: string, @Res() response: Response) { return response.sendFile(this.kycStorage.getPrivatePath(objectKey)); }
  @Post('admin/delivery-onboarding/:uid/verify') @Roles('ADMIN') verifyDelivery(@Param('uid') uid: string) { return this.service.verify(uid, 'DELIVERY'); }
  @Post('admin/delivery-onboarding/:uid/reject') @Roles('ADMIN') rejectDelivery(@Param('uid') uid: string, @Body('reason') reason?: string) { return this.service.reject(uid, 'DELIVERY', reason); }
  @Post('admin/delivery-onboarding/:uid/documents/:type/verify') @Roles('ADMIN') verifyDeliveryDocument(@Param('uid') uid: string, @Param('type') type: string) { return this.service.setDocumentStatus(uid, 'DELIVERY', type, 'VERIFIED'); }
  @Post('admin/delivery-onboarding/:uid/documents/:type/reject') @Roles('ADMIN') rejectDeliveryDocument(@Param('uid') uid: string, @Param('type') type: string) { return this.service.setDocumentStatus(uid, 'DELIVERY', type, 'REJECTED'); }
}
