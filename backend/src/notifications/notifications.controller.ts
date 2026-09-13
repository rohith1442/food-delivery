import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';

import { AuthGuard } from '../auth/auth.guard.js';
import { NotificationsService } from './notifications.service.js';

@Controller('notifications')
@UseGuards(AuthGuard)
export class NotificationsController {
  constructor(
    private readonly notificationsService: NotificationsService,
  ) {}

  @Post('device-token')
  async registerDeviceToken(
    @Req() request: any,
    @Body()
    body: {
      token: string;
      app: string;
      platform: string;
    },
  ) {
    if (!body.token?.trim()) {
      throw new BadRequestException(
        'FCM token is required',
      );
    }

    return this.notificationsService.registerDeviceToken(
      request.user.uid,
      body,
    );
  }

  @Get()
  async getNotifications(@Req() request: any) {
    return this.notificationsService.getNotifications(request.user.uid);
  }

  @Patch('read-all')
  async markAllRead(@Req() request: any) {
    return this.notificationsService.markAllNotificationsRead(request.user.uid);
  }

  @Patch(':notificationId/read')
  async markRead(
    @Req() request: any,
    @Param('notificationId') notificationId: string,
  ) {
    return this.notificationsService.markNotificationRead(
      request.user.uid,
      notificationId,
    );
  }
}
