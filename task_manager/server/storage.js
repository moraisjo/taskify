const { v4: uuidv4 } = require('uuid');

class ServerStorage {
  constructor() {
    this.tasks = new Map();
    this.lastModified = new Map(); // Rastreamento de modificações
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
}

module.exports = new ServerStorage();
