wl = WorldLocation.find_by(slug: "eswatini")
WorldLocationNewsPageWorker.perform_async_in_queue("bulk_republishing", wl.id)
