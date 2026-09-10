import {
  Body,
  Controller,
  Get,
  Headers,
  Post,
  UnauthorizedException,
} from '@nestjs/common';

import { AuthService } from './auth.service.js';

@Controller('auth')
export class AuthController {
  constructor(
    private readonly authService: AuthService,
  ) {}

  @Get('me')
  async getCurrentUser(
    @Headers('authorization')
    authorization?: string,
  ) {
    const decodedToken =
      await this.getDecodedToken(
        authorization,
      );

    const user =
      await this.authService.getUser(
        decodedToken.uid,
      );

    return {
      uid: decodedToken.uid,

      email:
        decodedToken.email ?? null,

      phoneNumber:
        decodedToken.phone_number ??
        null,

      user,
    };
  }

  @Post('register/merchant')
  async registerMerchant(
    @Headers('authorization')
    authorization: string | undefined,

    @Body()
    body: {
      name?: string;
      businessName?: string;
    },
  ) {
    const decodedToken =
      await this.getDecodedToken(
        authorization,
      );

    return this.authService
      .registerMerchant(
        decodedToken.uid,
        {
          email:
            decodedToken.email ??
            null,

          phoneNumber:
            decodedToken.phone_number ??
            null,

          name:
            body.name,

          businessName:
            body.businessName,
        },
      );
  }

  @Post('register/customer')
async registerCustomer(
  @Headers('authorization')
  authorization: string | undefined,

  @Body()
  body: {
    name?: string;
  },
) {
  const decodedToken =
    await this.getDecodedToken(
      authorization,
    );

  return this.authService
    .registerCustomer(
      decodedToken.uid,
      {
        email:
          decodedToken.email ??
          null,

        phoneNumber:
          decodedToken.phone_number ??
          null,

        name:
          body.name,
      },
    );
}

  @Post('register/delivery')
  async registerDelivery(
    @Headers('authorization')
    authorization: string | undefined,

    @Body()
    body: {
      name?: string;
    },
  ) {
    const decodedToken =
      await this.getDecodedToken(
        authorization,
      );

    return this.authService
      .registerDelivery(
        decodedToken.uid,
        {
          email:
            decodedToken.email ??
            null,

          phoneNumber:
            decodedToken.phone_number ??
            null,

          name:
            body.name,
        },
      );
  }

  private async getDecodedToken(
    authorization?: string,
  ) {
    if (
      !authorization?.startsWith(
        'Bearer ',
      )
    ) {
      throw new UnauthorizedException(
        'Authorization token is required',
      );
    }

    const token =
      authorization.substring(7);

    return this.authService
      .verifyToken(token);
  }
}