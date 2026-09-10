import Foundation
import Supabase

enum SyncEngine {
    private static var pushTask: Task<Void, Never>?

    private static let tasksKey = "tasks_v1"
    private static let diaryKey = "diary_v1"

    static func fullSync(state: AppState) async {
        guard let ownerId = state.careDataOwnerId ?? state.sessionUserId else { return }

        let localTasks = Persistence.load(
            [TaskItem].self,
            key: tasksKey,
            userId: ownerId,
            defaultValue: []
        )
        let localDiary = Persistence.load(
            [DiaryEntry].self,
            key: diaryKey,
            userId: ownerId,
            defaultValue: []
        )

        struct RemoteRow: Decodable {
            let payload: Data
        }

        let client = SupabaseClientProvider.shared.client
        var remoteTasks: [TaskItem] = []
        var remoteDiary: [DiaryEntry] = []

        do {
            let rows: [RemoteRow] = try await client.database
                .from("tasks")
                .select("payload")
                .eq("user_id", value: ownerId)
                .execute()
                .value
            remoteTasks = rows.compactMap {
                try? JSONDecoder().decode(TaskItem.self, from: $0.payload)
            }
        } catch {
            print("Task sync download failed: \(error)")
        }

        do {
            let rows: [RemoteRow] = try await client.database
                .from("diary_entries")
                .select("payload")
                .eq("user_id", value: ownerId)
                .execute()
                .value
            remoteDiary = rows.compactMap {
                try? JSONDecoder().decode(DiaryEntry.self, from: $0.payload)
            }
        } catch {
            print("Diary sync download failed: \(error)")
        }

        let mergedTasks = mergeByUpdatedAt(
            local: localTasks,
            remote: remoteTasks,
            id: { $0.id },
            updatedAt: { $0.updatedAt }
        )
        let mergedDiary = mergeByUpdatedAt(
            local: localDiary,
            remote: remoteDiary,
            id: { $0.id },
            updatedAt: { $0.updatedAt }
        )

        Persistence.save(mergedTasks, key: tasksKey, userId: ownerId)
        Persistence.save(mergedDiary, key: diaryKey, userId: ownerId)
        state.tasks = mergedTasks
        state.diary = mergedDiary

        schedulePush(state: state)
    }

    static func schedulePush(state: AppState) {
        pushTask?.cancel()
        pushTask = Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard !Task.isCancelled else { return }
            await pushNow(state: state)
        }
    }

    static func deleteTask(id: UUID, state: AppState) async {
        await deleteRemoteItem(table: "tasks", id: id, state: state)
    }

    static func deleteDiaryEntry(id: UUID, state: AppState) async {
        await deleteRemoteItem(table: "diary_entries", id: id, state: state)
    }

    private static func deleteRemoteItem(table: String, id: UUID, state: AppState) async {
        guard let ownerId = state.careDataOwnerId ?? state.sessionUserId else { return }
        do {
            try await SupabaseClientProvider.shared.client.database
                .from(table)
                .delete()
                .eq("user_id", value: ownerId)
                .eq("item_id", value: id.uuidString)
                .execute()
        } catch {
            print("Remote delete failed for \(table): \(error)")
        }
    }

    private static func pushNow(state: AppState) async {
        guard let ownerId = state.careDataOwnerId ?? state.sessionUserId else { return }
        let client = SupabaseClientProvider.shared.client

        struct TaskRow: Encodable {
            let user_id: String
            let item_id: String
            let payload: Data
            let updated_at: Date
            let created_at: Date
        }

        struct DiaryRow: Encodable {
            let user_id: String
            let item_id: String
            let payload: Data
            let updated_at: Date
            let created_at: Date
        }

        let taskRows = state.tasks.map { task in
            TaskRow(
                user_id: ownerId,
                item_id: task.id.uuidString,
                payload: (try? JSONEncoder().encode(task)) ?? Data(),
                updated_at: task.updatedAt,
                created_at: task.createdAt
            )
        }

        let diaryRows = state.diary.map { entry in
            DiaryRow(
                user_id: ownerId,
                item_id: entry.id.uuidString,
                payload: (try? JSONEncoder().encode(entry)) ?? Data(),
                updated_at: entry.updatedAt,
                created_at: entry.createdAt
            )
        }

        if !taskRows.isEmpty {
            do {
                try await client.database
                    .from("tasks")
                    .upsert(taskRows, onConflict: "user_id,item_id")
                    .execute()
            } catch {
                print("Task sync upload failed: \(error)")
            }
        }

        if !diaryRows.isEmpty {
            do {
                try await client.database
                    .from("diary_entries")
                    .upsert(diaryRows, onConflict: "user_id,item_id")
                    .execute()
            } catch {
                print("Diary sync upload failed: \(error)")
            }
        }
    }

    private static func mergeByUpdatedAt<T, Key: Hashable>(
        local: [T],
        remote: [T],
        id: (T) -> Key,
        updatedAt: (T) -> Date
    ) -> [T] {
        var items: [Key: T] = [:]
        for localItem in local { items[id(localItem)] = localItem }
        for remoteItem in remote {
            let key = id(remoteItem)
            if let existing = items[key] {
                if updatedAt(remoteItem) > updatedAt(existing) {
                    items[key] = remoteItem
                }
            } else {
                items[key] = remoteItem
            }
        }
        return Array(items.values)
    }
}
