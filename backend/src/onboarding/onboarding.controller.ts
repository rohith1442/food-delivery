import { Body, Controller, Get, Param, Post, Put, Req, UseGuards } from '@nestjs/common';
import { AuthGuard } from '../auth/auth.guard.js';
import { Roles } from '../auth/roles.decorator.js';
import { RolesGuard } from '../auth/roles.guard.js';
import { OnboardingService } from './onboarding.service.js';

@Controller()
@UseGuards(AuthGuard, RolesGuard)
export class OnboardingController {
  constructor(private readonly service: OnboardingService) {}
  @Get('merchant/onboarding') @Roles('MERCHANT') getMerchant(@Req() req: any) { return this.service.get(req.user.uid, 'MERCHANT'); }
  @Put('merchant/onboarding') @Roles('MERCHANT') updateMerchant(@Req() req: any, @Body() body: Record<string, unknown>) { return this.service.update(req.user.uid, 'MERCHANT', body); }
  @Post('merchant/onboarding/submit') @Roles('MERCHANT') submitMerchant(@Req() req: any) { return this.service.submit(req.user.uid, 'MERCHANT'); }
  @Post('merchant/onboarding/documents') @Roles('MERCHANT') documentMerchant(@Req() req: any, @Body() body: Record<string, unknown>) { return this.service.addDocument(req.user.uid, 'MERCHANT', body); }
  @Get('delivery/onboarding') @Roles('DELIVERY') getDelivery(@Req() req: any) { return this.service.get(req.user.uid, 'DELIVERY'); }
  @Put('delivery/onboarding') @Roles('DELIVERY') updateDelivery(@Req() req: any, @Body() body: Record<string, unknown>) { return this.service.update(req.user.uid, 'DELIVERY', body); }
  @Post('delivery/onboarding/submit') @Roles('DELIVERY') submitDelivery(@Req() req: any) { return this.service.submit(req.user.uid, 'DELIVERY'); }
  @Post('delivery/onboarding/documents') @Roles('DELIVERY') documentDelivery(@Req() req: any, @Body() body: Record<string, unknown>) { return this.service.addDocument(req.user.uid, 'DELIVERY', body); }
  @Get('admin/merchant-onboarding') @Roles('ADMIN') listMerchants() { return this.service.list('MERCHANT'); }
  @Get('admin/merchant-onboarding/:uid') @Roles('ADMIN') getMerchantAdmin(@Param('uid') uid: string) { return this.service.getAdmin(uid, 'MERCHANT'); }
  @Post('admin/merchant-onboarding/:uid/verify') @Roles('ADMIN') verifyMerchant(@Param('uid') uid: string) { return this.service.verify(uid, 'MERCHANT'); }
  @Post('admin/merchant-onboarding/:uid/reject') @Roles('ADMIN') rejectMerchant(@Param('uid') uid: string, @Body('reason') reason?: string) { return this.service.reject(uid, 'MERCHANT', reason); }
  @Post('admin/merchant-onboarding/:uid/create-linked-account') @Roles('ADMIN') linkMerchant(@Param('uid') uid: string) { return this.service.createLinkedAccount(uid); }
  @Get('admin/delivery-onboarding') @Roles('ADMIN') listDelivery() { return this.service.list('DELIVERY'); }
  @Get('admin/delivery-onboarding/:uid') @Roles('ADMIN') getDeliveryAdmin(@Param('uid') uid: string) { return this.service.getAdmin(uid, 'DELIVERY'); }
  @Post('admin/delivery-onboarding/:uid/verify') @Roles('ADMIN') verifyDelivery(@Param('uid') uid: string) { return this.service.verify(uid, 'DELIVERY'); }
  @Post('admin/delivery-onboarding/:uid/reject') @Roles('ADMIN') rejectDelivery(@Param('uid') uid: string, @Body('reason') reason?: string) { return this.service.reject(uid, 'DELIVERY', reason); }
}
