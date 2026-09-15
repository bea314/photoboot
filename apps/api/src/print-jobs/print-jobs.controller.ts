import { Body, Controller, Param, Patch, Post } from '@nestjs/common';
import { CreatePrintJobDto } from './dto/create-print-job.dto';
import { UpdatePrintJobDto } from './dto/update-print-job.dto';
import { PrintJobsService } from './print-jobs.service';

@Controller('print-jobs')
export class PrintJobsController {
  constructor(private readonly printJobsService: PrintJobsService) {}

  @Post()
  create(@Body() dto: CreatePrintJobDto) {
    return this.printJobsService.create(dto);
  }

  @Patch(':id')
  update(@Param('id') id: string, @Body() dto: UpdatePrintJobDto) {
    return this.printJobsService.update(id, dto);
  }
}
