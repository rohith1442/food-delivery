import { SetMetadata } from '@nestjs/common';

export const ROLES_KEY = 'roles';

export type UserRole =
  | 'CUSTOMER'
  | 'MERCHANT'
  | 'DELIVERY'
  | 'ADMIN';

export const Roles = (...roles: UserRole[]) =>
  SetMetadata(ROLES_KEY, roles);