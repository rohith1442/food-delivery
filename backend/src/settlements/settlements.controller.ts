import { Controller, Get, Param, Req, UseGuards } from '@nestjs/common';
import { AuthGuard } from '../auth/auth.guard.js';
import { Roles } from '../auth/roles.decorator.js';
import { RolesGuard } from '../auth/roles.guard.js';
import { SettlementsService } from './settlements.service.js';
@Controller('settlements')
@UseGuards(AuthGuard, RolesGuard)
@Roles('ADMIN')
export class SettlementsController { constructor(private readonly service: SettlementsService) {} @Get(':orderId') get(@Param('orderId') orderId: string) { return this.service.finalizeOrderSettlement(orderId); } }

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
