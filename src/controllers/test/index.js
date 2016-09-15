import Logger from 'src/common/logger';
import FileSystem from 'src/common/file_system';
import config from 'src/common/config';
import path from 'path';
import randomstring from 'randomstring';
import {spawnSync} from 'child_process';

let logger = new Logger('TestController');
let fileSystem = new FileSystem();

export default class TestController {
  constructor(server) {
    this._server = server;
    this._elastalertPath = config.get('elastalertPath');
    this.testFolder = this._getTestFolder();

    fileSystem.createDirectoryIfNotExists(this.testFolder).catch(function (error) {
      logger.error(`Failed to create the test folder in ${this.testFolder} with error:`, error);
    });
  }

  testRule(rule, options) {
    const self = this;
    let tempFileName = '~' + randomstring.generate() + '.temp';
    let tempFilePath = path.join(self.testFolder, tempFileName);

    return new Promise(function (resolve, reject) {
      fileSystem.writeFile(tempFilePath, rule)
        .then(function () {
          let processOptions = [];
          let stdoutLines = [];
          let stderrLines = [];

          processOptions.push(tempFilePath);
          processOptions.push('--days', options.days);

          if (options.alert) {
            processOptions.push('--alert');
          }

          switch (options.testType) {
            case 'schemaOnly': processOptions.push('--schema-only'); break;
            case 'countOnly': processOptions.push('--count-only'); break;
          }

          let testProcess = spawnSync('elastalert-test-rule', processOptions, {
            cwd: self._elastalertPath
          });

          testProcess.stdout.on('data', function (data) {
            stdoutLines.push(data.toString());
            logger.info(data.toString());
          });

          testProcess.stderr.on('data', function (data) {
            stderrLines.push(data.toString());
            logger.error(data.toString());
          });

          testProcess.on('exit', function (statusCode) {
            console.log('Test exited');
            if (statusCode === 0) {
              resolve(stdoutLines.join('\n'));
            } else {
              reject(stderrLines.join('\n'));
            }
          });
        })
        .catch(function (error) {
          logger.error(`Failed to write file ${tempFileName} to ${self.testFolder} with error`, error);
          reject(error);
        });
    });
  }

  _getTestFolder() {
    return path.join(this._server.getDataFolder(), 'tests');
  }
}
