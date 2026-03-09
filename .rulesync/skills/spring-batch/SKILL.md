---
name: spring-batch
description: "Spring Batch: job/step design, chunk processing, readers/writers/processors, scheduling"
targets: ["claudecode"]
claudecode:
  model: sonnet
---

# Spring Batch

Comprehensive guide for Spring Batch: job and step design, chunk-oriented processing, built-in readers/writers, error handling, and
scheduling.

## Core Concepts

- **Job**: A complete batch process (e.g., "daily order export")
- **Step**: A single phase within a Job (e.g., "read orders → transform → write CSV")
- **Chunk**: A group of items processed together in a single transaction
- **ItemReader**: Reads data from a source
- **ItemProcessor**: Transforms/validates data
- **ItemWriter**: Writes processed data to a destination

## Job and Step Configuration

### Kotlin

```kotlin
@Configuration
class OrderExportJobConfig(
    private val jobRepository: JobRepository,
    private val transactionManager: PlatformTransactionManager
) {

    @Bean
    fun orderExportJob(exportStep: Step, cleanupStep: Step): Job =
        JobBuilder("orderExportJob", jobRepository)
            .start(exportStep)
            .next(cleanupStep)
            .listener(jobExecutionListener())
            .build()

    @Bean
    fun exportStep(
        reader: ItemReader<Order>,
        processor: ItemProcessor<Order, OrderCsvRecord>,
        writer: ItemWriter<OrderCsvRecord>
    ): Step =
        StepBuilder("exportStep", jobRepository)
            .chunk<Order, OrderCsvRecord>(100, transactionManager)
            .reader(reader)
            .processor(processor)
            .writer(writer)
            .faultTolerant()
            .skipLimit(10)
            .skip(FlatFileParseException::class.java)
            .retryLimit(3)
            .retry(DeadlockLoserDataAccessException::class.java)
            .listener(stepExecutionListener())
            .build()

    @Bean
    fun cleanupStep(tasklet: Tasklet): Step =
        StepBuilder("cleanupStep", jobRepository)
            .tasklet(tasklet, transactionManager)
            .build()
}
```

### Java

```java
@Configuration
public class OrderExportJobConfig {

    private final JobRepository jobRepository;
    private final PlatformTransactionManager transactionManager;

    public OrderExportJobConfig(JobRepository jobRepository,
                                 PlatformTransactionManager transactionManager) {
        this.jobRepository = jobRepository;
        this.transactionManager = transactionManager;
    }

    @Bean
    public Job orderExportJob(Step exportStep, Step cleanupStep) {
        return new JobBuilder("orderExportJob", jobRepository)
            .start(exportStep)
            .next(cleanupStep)
            .listener(jobExecutionListener())
            .build();
    }

    @Bean
    public Step exportStep(ItemReader<Order> reader,
                           ItemProcessor<Order, OrderCsvRecord> processor,
                           ItemWriter<OrderCsvRecord> writer) {
        return new StepBuilder("exportStep", jobRepository)
            .<Order, OrderCsvRecord>chunk(100, transactionManager)
            .reader(reader)
            .processor(processor)
            .writer(writer)
            .faultTolerant()
            .skipLimit(10)
            .skip(FlatFileParseException.class)
            .retryLimit(3)
            .retry(DeadlockLoserDataAccessException.class)
            .build();
    }
}
```

## Built-In Readers

### JdbcCursorItemReader

```kotlin
@Bean
fun orderReader(dataSource: DataSource): JdbcCursorItemReader<Order> =
    JdbcCursorItemReaderBuilder<Order>()
        .name("orderReader")
        .dataSource(dataSource)
        .sql("SELECT id, customer_id, total_amount, status, created_at FROM orders WHERE status = ?")
        .preparedStatementSetter { ps -> ps.setString(1, "COMPLETED") }
        .rowMapper { rs, _ ->
            Order(
                id = rs.getLong("id"),
                customerId = rs.getString("customer_id"),
                totalAmount = rs.getBigDecimal("total_amount"),
                status = OrderStatus.valueOf(rs.getString("status")),
                createdAt = rs.getTimestamp("created_at").toInstant()
            )
        }
        .build()
```

### JpaPagingItemReader

```kotlin
@Bean
fun orderJpaReader(entityManagerFactory: EntityManagerFactory): JpaPagingItemReader<Order> =
    JpaPagingItemReaderBuilder<Order>()
        .name("orderJpaReader")
        .entityManagerFactory(entityManagerFactory)
        .queryString("SELECT o FROM Order o WHERE o.status = :status ORDER BY o.createdAt")
        .parameterValues(mapOf("status" to OrderStatus.COMPLETED))
        .pageSize(100)
        .build()
```

### FlatFileItemReader (CSV)

```kotlin
@Bean
fun csvReader(): FlatFileItemReader<OrderCsvInput> =
    FlatFileItemReaderBuilder<OrderCsvInput>()
        .name("csvReader")
        .resource(ClassPathResource("input/orders.csv"))
        .linesToSkip(1) // Skip header
        .delimited()
        .delimiter(",")
        .names("orderId", "customerId", "amount", "date")
        .fieldSetMapper { fieldSet ->
            OrderCsvInput(
                orderId = fieldSet.readString("orderId"),
                customerId = fieldSet.readString("customerId"),
                amount = fieldSet.readBigDecimal("amount"),
                date = fieldSet.readString("date")
            )
        }
        .build()
```

## ItemProcessor

### Kotlin

```kotlin
@Component
class OrderExportProcessor(
    private val currencyService: CurrencyService
) : ItemProcessor<Order, OrderCsvRecord> {

    override fun process(order: Order): OrderCsvRecord? {
        // Return null to skip this item
        if (order.totalAmount <= BigDecimal.ZERO) {
            return null
        }

        val convertedAmount = currencyService.convertToUsd(order.totalAmount)

        return OrderCsvRecord(
            orderId = order.id.toString(),
            customerId = order.customerId,
            amount = convertedAmount.setScale(2, RoundingMode.HALF_UP).toString(),
            status = order.status.name,
            date = order.createdAt.toString()
        )
    }
}
```

### Composite Processor

```kotlin
@Bean
fun compositeProcessor(
    validationProcessor: ItemProcessor<Order, Order>,
    transformProcessor: ItemProcessor<Order, OrderCsvRecord>
): CompositeItemProcessor<Order, OrderCsvRecord> =
    CompositeItemProcessorBuilder<Order, OrderCsvRecord>()
        .delegates(listOf(validationProcessor, transformProcessor))
        .build()
```

## Built-In Writers

### JdbcBatchItemWriter

```kotlin
@Bean
fun jdbcWriter(dataSource: DataSource): JdbcBatchItemWriter<OrderCsvRecord> =
    JdbcBatchItemWriterBuilder<OrderCsvRecord>()
        .dataSource(dataSource)
        .sql("INSERT INTO order_exports (order_id, customer_id, amount, status, export_date) " +
             "VALUES (:orderId, :customerId, :amount, :status, :date)")
        .beanMapped()
        .build()
```

### FlatFileItemWriter (CSV)

```kotlin
@Bean
fun csvWriter(): FlatFileItemWriter<OrderCsvRecord> =
    FlatFileItemWriterBuilder<OrderCsvRecord>()
        .name("csvWriter")
        .resource(FileSystemResource("output/orders-export.csv"))
        .headerCallback { writer -> writer.write("OrderId,CustomerId,Amount,Status,Date") }
        .delimited()
        .delimiter(",")
        .names("orderId", "customerId", "amount", "status", "date")
        .build()
```

### JpaItemWriter

```kotlin
@Bean
fun jpaWriter(entityManagerFactory: EntityManagerFactory): JpaItemWriter<OrderExport> =
    JpaItemWriterBuilder<OrderExport>()
        .entityManagerFactory(entityManagerFactory)
        .build()
```

### Composite Writer

```kotlin
@Bean
fun compositeWriter(
    csvWriter: FlatFileItemWriter<OrderCsvRecord>,
    jdbcWriter: JdbcBatchItemWriter<OrderCsvRecord>
): CompositeItemWriter<OrderCsvRecord> =
    CompositeItemWriterBuilder<OrderCsvRecord>()
        .delegates(listOf(csvWriter, jdbcWriter))
        .build()
```

## Job Parameters and Execution Context

### Kotlin

```kotlin
@Bean
@StepScope
fun parameterizedReader(
    @Value("#{jobParameters['startDate']}") startDate: String,
    @Value("#{jobParameters['endDate']}") endDate: String,
    dataSource: DataSource
): JdbcCursorItemReader<Order> =
    JdbcCursorItemReaderBuilder<Order>()
        .name("parameterizedReader")
        .dataSource(dataSource)
        .sql("SELECT * FROM orders WHERE created_at BETWEEN ? AND ?")
        .preparedStatementSetter { ps ->
            ps.setString(1, startDate)
            ps.setString(2, endDate)
        }
        .rowMapper(OrderRowMapper())
        .build()

// Launching with parameters
@Service
class JobLaunchService(
    private val jobLauncher: JobLauncher,
    private val orderExportJob: Job
) {
    fun launchExport(startDate: LocalDate, endDate: LocalDate): JobExecution {
        val params = JobParametersBuilder()
            .addString("startDate", startDate.toString())
            .addString("endDate", endDate.toString())
            .addLong("timestamp", System.currentTimeMillis())
            .toJobParameters()
        return jobLauncher.run(orderExportJob, params)
    }
}
```

## Step Flow: Sequential, Conditional, Parallel

### Conditional Flow

```kotlin
@Bean
fun conditionalJob(
    validateStep: Step,
    processStep: Step,
    errorStep: Step,
    successStep: Step
): Job =
    JobBuilder("conditionalJob", jobRepository)
        .start(validateStep)
        .on("FAILED").to(errorStep)
        .from(validateStep).on("*").to(processStep)
        .from(processStep).on("COMPLETED").to(successStep)
        .end()
        .build()
```

### Parallel Steps

```kotlin
@Bean
fun parallelJob(
    partitionStep: Step,
    aggregateStep: Step
): Job =
    JobBuilder("parallelJob", jobRepository)
        .start(splitFlow(step1(), step2(), step3()))
        .next(aggregateStep)
        .build()

private fun splitFlow(vararg steps: Step): Flow {
    val flows = steps.map { step ->
        FlowBuilder<SimpleFlow>("flow_${step.name}")
            .start(step)
            .build()
    }.toTypedArray()

    return FlowBuilder<SimpleFlow>("splitFlow")
        .split(SimpleAsyncTaskExecutor())
        .add(*flows)
        .build()
}
```

## Partitioning

```kotlin
@Bean
fun partitionedStep(workerStep: Step): Step =
    StepBuilder("partitionedStep", jobRepository)
        .partitioner("workerStep", rangePartitioner())
        .step(workerStep)
        .gridSize(4)
        .taskExecutor(SimpleAsyncTaskExecutor())
        .build()

@Bean
fun rangePartitioner(): Partitioner = Partitioner { gridSize ->
    val totalRecords = orderRepository.count()
    val rangeSize = totalRecords / gridSize
    (0 until gridSize).associate { i ->
        "partition$i" to ExecutionContext().apply {
            putLong("minId", i * rangeSize + 1)
            putLong("maxId", if (i == gridSize - 1) totalRecords else (i + 1) * rangeSize)
        }
    }
}
```

## Error Handling

### Skip Policy

```kotlin
@Bean
fun faultTolerantStep(): Step =
    StepBuilder("faultTolerantStep", jobRepository)
        .chunk<Order, OrderCsvRecord>(100, transactionManager)
        .reader(reader)
        .processor(processor)
        .writer(writer)
        .faultTolerant()
        .skipLimit(50)
        .skip(ValidationException::class.java)
        .skip(FlatFileParseException::class.java)
        .noSkip(DatabaseException::class.java)
        .listener(skipListener())
        .build()

@Component
class OrderSkipListener : SkipListener<Order, OrderCsvRecord> {
    private val logger = LoggerFactory.getLogger(javaClass)

    override fun onSkipInRead(t: Throwable) {
        logger.warn("Skipped during read: ${t.message}")
    }

    override fun onSkipInProcess(item: Order, t: Throwable) {
        logger.warn("Skipped order ${item.id} during process: ${t.message}")
    }

    override fun onSkipInWrite(item: OrderCsvRecord, t: Throwable) {
        logger.warn("Skipped record ${item.orderId} during write: ${t.message}")
    }
}
```

### Retry Policy

```kotlin
.faultTolerant()
.retryLimit(3)
.retry(OptimisticLockingFailureException::class.java)
.retry(DeadlockLoserDataAccessException::class.java)
.noRetry(ValidationException::class.java)
```

## Job Scheduling

### With @Scheduled

```kotlin
@Component
class JobScheduler(
    private val jobLauncher: JobLauncher,
    private val orderExportJob: Job
) {

    @Scheduled(cron = "0 0 2 * * *") // Daily at 2 AM
    fun runDailyExport() {
        val params = JobParametersBuilder()
            .addLong("timestamp", System.currentTimeMillis())
            .addString("date", LocalDate.now().minusDays(1).toString())
            .toJobParameters()
        jobLauncher.run(orderExportJob, params)
    }
}
```

## Testing Batch Jobs

### Kotlin

```kotlin
@SpringBatchTest
@SpringBootTest
class OrderExportJobTest {

    @Autowired
    private lateinit var jobLauncherTestUtils: JobLauncherTestUtils

    @Autowired
    private lateinit var jobRepositoryTestUtils: JobRepositoryTestUtils

    @Autowired
    private lateinit var orderRepository: OrderRepository

    @BeforeEach
    fun setup() {
        jobRepositoryTestUtils.removeJobExecutions()
    }

    @Test
    fun `should complete export job successfully`() {
        // Setup test data
        orderRepository.saveAll(listOf(
            Order(customerId = "c1", totalAmount = BigDecimal("100.00"), status = OrderStatus.COMPLETED),
            Order(customerId = "c2", totalAmount = BigDecimal("200.00"), status = OrderStatus.COMPLETED)
        ))

        val params = JobParametersBuilder()
            .addLong("timestamp", System.currentTimeMillis())
            .toJobParameters()

        val execution = jobLauncherTestUtils.launchJob(params)

        assertEquals(BatchStatus.COMPLETED, execution.status)
        assertEquals(2, execution.stepExecutions.first().writeCount)
    }

    @Test
    fun `should skip invalid records`() {
        orderRepository.saveAll(listOf(
            Order(customerId = "c1", totalAmount = BigDecimal("100.00"), status = OrderStatus.COMPLETED),
            Order(customerId = "c2", totalAmount = BigDecimal.ZERO, status = OrderStatus.COMPLETED),
            Order(customerId = "c3", totalAmount = BigDecimal("300.00"), status = OrderStatus.COMPLETED)
        ))

        val execution = jobLauncherTestUtils.launchJob()

        assertEquals(BatchStatus.COMPLETED, execution.status)
        val stepExecution = execution.stepExecutions.first()
        assertEquals(3, stepExecution.readCount)
        assertEquals(2, stepExecution.writeCount)
        assertEquals(1, stepExecution.filterCount)
    }

    @Test
    fun `should test single step`() {
        val execution = jobLauncherTestUtils.launchStep("exportStep")
        assertEquals(BatchStatus.COMPLETED, execution.status)
    }
}
```

## Best Practices

1. **Choose appropriate chunk size** — 100-1000 items, balance memory vs transaction overhead
2. **Use @StepScope** for late-binding of job parameters
3. **Configure skip and retry** — always handle expected errors gracefully
4. **Use partitioning** for large datasets to enable parallel processing
5. **Monitor with actuator** — expose batch job metrics
6. **Test individual steps** — use `launchStep()` for isolated testing
7. **Idempotent jobs** — design jobs to be safely re-runnable
8. **Clean up job metadata** — purge old executions from repository tables
9. **Use Tasklet** for simple steps (file cleanup, notifications)
10. **Log skip/retry events** — implement SkipListener for observability
