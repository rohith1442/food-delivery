import {
  Controller,
  Get,
  Param,
  Query,
} from '@nestjs/common';

import { SettingsService } from './settings.service.js';

@Controller('settings')
export class SettingsController {
  constructor(
    private readonly settingsService: SettingsService,
  ) {}

  @Get('app-config')
  async getAppConfig(
    @Query('app') app: string,
  ) {
    return this.settingsService.getAppConfig(
      app,
    );
  }

  @Get('content')
  async getContent() { return this.settingsService.getContent(); }

  @Get('content/:type')
  async getContentByType(@Param('type') type: string) { return this.settingsService.getContentByType(type); }
}
