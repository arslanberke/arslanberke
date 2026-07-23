import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsBoolean, IsIn, IsOptional, IsString, MaxLength } from 'class-validator';

export class UpdateSettingsDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(100)
  name?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  darkMode?: boolean;

  @ApiPropertyOptional({ enum: ['en', 'tr'] })
  @IsOptional()
  @IsIn(['en', 'tr'])
  language?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  emailNotifications?: boolean;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  pushNotifications?: boolean;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  inAppNotifications?: boolean;
}

export class RegisterDeviceDto {
  @ApiPropertyOptional()
  @IsString()
  token: string;

  @ApiPropertyOptional({ enum: ['ios', 'android', 'web'] })
  @IsIn(['ios', 'android', 'web'])
  platform: string;
}
