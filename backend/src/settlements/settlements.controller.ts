import { Controller, Get, Param, Post, Req, UseGuards } from '@nestjs/common';
import { AuthGuard } from '../auth/auth.guard.js';
import { Roles } from '../auth/roles.decorator.js';
import { RolesGuard } from '../auth/roles.guard.js';
import { SettlementsService } from './settlements.service.js';
@Controller('settlements')
@UseGuards(AuthGuard, RolesGuard)
@Roles('ADMIN')
export class SettlementsController { constructor(private readonly service: SettlementsService) {} @Get() list() { return this.service.getAllSettlements(); } @Get(':orderId') get(@Param('orderId') orderId: string) { return this.service.getOrderSettlements(orderId); } @Post(':orderId/finalize') finalize(@Param('orderId') orderId: string) { return this.service.finalizeOrderSettlement(orderId); } @Post(':orderId/retry') retry(@Param('orderId') orderId: string) { return this.service.retryMerchantSettlement(orderId); } }

@Controller('admin/payouts')
@UseGuards(AuthGuard, RolesGuard)
@Roles('ADMIN')
export class AdminPayoutController {
  constructor(private readonly service: SettlementsService) {}
  @Post('riders/:riderId') payout(@Param('riderId') riderId: string) { return this.service.payoutRider(riderId); }
}

@Controller('merchant')
@UseGuards(AuthGuard, RolesGuard)
@Roles('MERCHANT')
export class MerchantSettlementsController {
  constructor(private readonly service: SettlementsService) {}
  @Get('earnings/summary') summary(@Req() req: any) { return this.service.getTransactions('MERCHANT', req.user.uid); }
  @Get('earnings/transactions') transactions(@Req() req: any) { return this.service.getTransactions('MERCHANT', req.user.uid); }
  @Get('settlements') settlements(@Req() req: any) { return this.service.getTransactions('MERCHANT', req.user.uid); }
}

@Controller('delivery')
@UseGuards(AuthGuard, RolesGuard)
@Roles('DELIVERY')
export class DeliverySettlementsController {
  constructor(private readonly service: SettlementsService) {}
  @Get('earnings') earnings(@Req() req: any) { return this.service.getTransactions('DELIVERY_PARTNER', req.user.uid); }
}
