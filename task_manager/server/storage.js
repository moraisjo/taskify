const { v4: uuidv4 } = require('uuid');
const fs = require('fs');
const path = require('path');

class ServerStorage {
  constructor() {
    this.tasks = new Map();
    this.lastModified = new Map(); // Rastreamento de modificações
    this.dataFile = path.join(__dirname, 'storage.json');
    this._loadFromDisk();
  }

  createTask(taskData) {
    const task = {
      id: taskData.id || uuidv4(),
      title: taskData.title,
      description: taskData.description || '',
      completed: taskData.completed || false,
      priority: taskData.priority || 'medium',
      userId: taskData.userId || 'user1',
      createdAt: taskData.createdAt || Date.now(),
      updatedAt: Date.now(),
      version: 1,
    };

    this.tasks.set(task.id, task);
    this.lastModified.set(task.id, task.updatedAt);
    this._persist();
    return task;
  }

  getTask(id) {
    return this.tasks.get(id) || null;
  }

  listTasks(userId, modifiedSince = null) {
    let tasks = Array.from(this.tasks.values()).filter((task) => task.userId === userId);

    if (modifiedSince) {
      tasks = tasks.filter((task) => task.updatedAt > modifiedSince);
    }

    return tasks.sort((a, b) => b.updatedAt - a.updatedAt);
  }

  updateTask(id, updates, clientVersion) {
    const task = this.tasks.get(id);
    if (!task) return { success: false, error: 'NOT_FOUND' };

    if (clientVersion && task.version !== clientVersion) {
      return {
        success: false,
        error: 'CONFLICT',
        serverTask: task,
      };
    }

    const updatedTask = {
      ...task,
      ...updates,
      id: task.id,
      userId: task.userId,
      createdAt: task.createdAt,
      updatedAt: Date.now(),
      version: task.version + 1,
    };

    this.tasks.set(id, updatedTask);
    this.lastModified.set(id, updatedTask.updatedAt);
    this._persist();

    return { success: true, task: updatedTask };
  }

  deleteTask(id, clientVersion) {
    const task = this.tasks.get(id);
    if (!task) return { success: false, error: 'NOT_FOUND' };

    if (clientVersion && task.version !== clientVersion) {
      return {
        success: false,
        error: 'CONFLICT',
        serverTask: task,
      };
    }

    this.tasks.delete(id);
    this.lastModified.delete(id);
    this._persist();
    return { success: true };
  }

  getLastSyncTimestamp(userId) {
    const userTasks = this.listTasks(userId);
    if (userTasks.length === 0) return 0;
    return Math.max(...userTasks.map((task) => task.updatedAt));
  }

  getStats(userId) {
    const tasks = this.listTasks(userId);
    const completed = tasks.filter((task) => task.completed).length;

    return {
      total: tasks.length,
      completed,
      pending: tasks.length - completed,
      lastSync: this.getLastSyncTimestamp(userId),
    };
  }

  _persist() {
    try {
      const content = {
        tasks: Array.from(this.tasks.values()),
      };
      fs.writeFileSync(this.dataFile, JSON.stringify(content, null, 2));
    } catch (err) {
      console.error('Erro ao persistir storage:', err);
    }
  }

  _loadFromDisk() {
    try {
      if (!fs.existsSync(this.dataFile)) return;
      const raw = fs.readFileSync(this.dataFile, 'utf-8');
      const parsed = JSON.parse(raw);
      if (parsed.tasks && Array.isArray(parsed.tasks)) {
        for (const t of parsed.tasks) {
          const task = {
            ...t,
            id: t.id,
            title: t.title || '',
            description: t.description || '',
            completed: !!t.completed,
            priority: t.priority || 'medium',
            userId: t.userId || 'user1',
            createdAt: t.createdAt || Date.now(),
            updatedAt: t.updatedAt || Date.now(),
            version: t.version || 1,
          };
          this.tasks.set(task.id, task);
          this.lastModified.set(task.id, task.updatedAt);
        }
      }
    } catch (err) {
      console.error('Erro ao carregar storage:', err);
    }
  }
}

module.exports = new ServerStorage();
