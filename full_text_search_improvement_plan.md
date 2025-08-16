# Full-Text Search Improvement Plan

## Overview (Current State)
- ✅ A tsvector column (`search_vector`) exists with a GIN index and trigger to keep it updated
- ✅ PostgreSQL extensions enabled: vector, unaccent, pg_trgm, uuid-ossp
- ✅ Keywords stored as PostgreSQL array with GIN index
- ✅ Basic full-text search using `search_content(query, limit: N)` method
- Current search uses simple OR logic with per-word similarity ratio

## Goals
Reduce write-time overhead, improve read performance and ranking quality, and simplify maintenance.

## Remaining Improvements

### 1. Replace Trigger with Generated (Stored) Column (PostgreSQL 12+)
**Why:** Avoid trigger overhead and keep the vector consistent automatically. Generated stored columns are computed by the database and persisted on disk.

**Plan (zero/minimal downtime):**
1. Add a new generated column with weights per field
2. Create a GIN index concurrently on the new column
3. Swap consumers to the new column (or rename columns)
4. Drop the old trigger, function, and index

**Example Migration:**
```ruby
class AddGeneratedSearchVector < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def up
    execute <<~SQL
      ALTER TABLE ragdoll_documents
      ADD COLUMN search_vector_v2 tsvector
      GENERATED ALWAYS AS (
        setweight(to_tsvector('english', coalesce(title, '')), 'A') ||
        setweight(to_tsvector('english', coalesce(metadata->>'summary', '')), 'B') ||
        setweight(to_tsvector('english', coalesce(metadata->>'keywords', '')), 'B') ||
        setweight(to_tsvector('english', coalesce(metadata->>'description', '')), 'C')
      ) STORED;
    SQL

    add_index :ragdoll_documents, :search_vector_v2, using: :gin, 
              algorithm: :concurrently, 
              name: 'index_ragdoll_docs_search_vector_v2_gin'

    # After verifying, drop old trigger/index/column and rename
  end

  def down
    remove_index :ragdoll_documents, name: 'index_ragdoll_docs_search_vector_v2_gin'
    remove_column :ragdoll_documents, :search_vector_v2
  end
end
```

### 2. Partial GIN Index on Processed Documents
**Why:** The query filters on `status = 'processed'`. A partial index reduces index size and speeds up scans.

**Migration:**
```ruby
add_index :ragdoll_documents, :search_vector, 
          using: :gin, 
          algorithm: :concurrently,
          name: 'index_ragdoll_docs_search_vector_processed_gin',
          where: "status = 'processed'"
```

### 3. Adopt websearch_to_tsquery for Natural Queries
**Why:** Supports quoted phrases, implicit AND/OR, and minus operator (e.g., "foo bar -baz").

**Implementation:**
```ruby
# In Document model
where("#{table_name}.search_vector @@ websearch_to_tsquery('english', ?)", query)
```

**Note:** If keeping the per-term ratio, split the original query for similarity calculation while using `websearch_to_tsquery` for filtering.

### 4. Improve Ranking with Weights and ts_rank
**Why:** Rank title hits higher than description/summary, leverage PostgreSQL's native ranking.

**Implementation:**
- Use weighted tsvector (see item #1)
- Replace or combine with current similarity ratio:

```ruby
select("*, ts_rank_cd(search_vector, websearch_to_tsquery('english', ?)) as rank", query)
  .where("search_vector @@ websearch_to_tsquery('english', ?)", query)
  .order("rank DESC, updated_at DESC")
```

### 5. Apply Unaccent for Accent-Insensitive Search
**Why:** Better international support (café matches cafe). Extension is already enabled but not used.

**Implementation:**
```ruby
# In generated column expression
GENERATED ALWAYS AS (
  setweight(to_tsvector('english', unaccent(coalesce(title, ''))), 'A') ||
  setweight(to_tsvector('english', unaccent(coalesce(metadata->>'summary', ''))), 'B')
  -- etc.
) STORED
```

### 6. Enhanced Keyword Array Search
**Current:** Keywords array with GIN index exists

**Improvement:** Use proper parameter binding:
```ruby
# Any overlap
where('keywords && ?::text[]', normalized_keywords)

# Contains all
where('keywords @> ?::text[]', normalized_keywords)
```

### 7. Internationalization / Language Support
**For multi-language documents:**
- Store language code per document
- Consider language-specific dictionaries or use 'simple' dictionary for universal support
- Option: Multiple search vectors per language

### 8. Operational Maintenance
- Monitor with `pg_stat_statements` for search query performance
- Regular `VACUUM ANALYZE` (auto-vacuum usually sufficient)
- Watch for index bloat with frequent updates

### 9. Benchmarking Guidance
**Before and after each change:**
- Use `EXPLAIN (ANALYZE, BUFFERS)`
- Measure:
  - Planning and execution time
  - Shared hit vs read ratios
  - Rows examined vs returned
  - Index usage (expect Bitmap Index Scan for GIN)

### 10. Instrumentation
- Log search timings and result counts
- Sample queries with EXPLAIN for regression detection
- Consider adding to SearchEngine service:
  ```ruby
  Rails.logger.info "[SEARCH] Query: #{query}, Results: #{results.count}, Time: #{elapsed}ms"
  ```

## Implementation Priority

**High Priority (Quick Wins):**
1. Partial index on processed documents (#2) - Easy, immediate benefit
2. websearch_to_tsquery (#3) - Better UX, minimal code change

**Medium Priority (Performance):**
3. Generated column with weights (#1) - Eliminates trigger overhead
4. ts_rank integration (#4) - Better ranking quality

**Low Priority (Nice to Have):**
5. Unaccent support (#5) - For international content
6. Multi-language support (#7) - As needed

## Notes
- Each improvement can be deployed independently
- Start with partial index for immediate gains
- Test on representative data volumes before production deployment