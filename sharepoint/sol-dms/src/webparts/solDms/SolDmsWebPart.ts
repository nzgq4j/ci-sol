import * as React from 'react';
import * as ReactDom from 'react-dom';
import { Version } from '@microsoft/sp-core-library';
import {
  type IPropertyPaneConfiguration,
  PropertyPaneTextField
} from '@microsoft/sp-property-pane';
import { BaseClientSideWebPart } from '@microsoft/sp-webpart-base';
import { AadHttpClient, SPHttpClient } from '@microsoft/sp-http';

import SolDms from './components/SolDms';
import { ISolDmsProps } from './components/ISolDmsProps';
import {
  createHttpServices,
  type HttpRequestExecutor,
  type OperationEndpoint,
  type SolDmsRuntimeConfig
} from '../../solDmsApp/services/http';

export interface ISolDmsWebPartProps {
  configurationUrl: string;
}

export default class SolDmsWebPart extends BaseClientSideWebPart<ISolDmsWebPartProps> {
  private _runtimeConfig: SolDmsRuntimeConfig = { mode: 'http', endpoints: {} };

  public render(): void {
    const executor: HttpRequestExecutor = { execute: (endpoint, init) => this._execute(endpoint, init) };
    const element: React.ReactElement<ISolDmsProps> = React.createElement(SolDms, {
      services: createHttpServices(this._runtimeConfig, executor)
    });
    ReactDom.render(element, this.domElement);
  }

  protected async onInit(): Promise<void> {
    await this._loadRuntimeConfiguration();
  }

  private async _loadRuntimeConfiguration(): Promise<void> {
    const configuredUrl = this.properties.configurationUrl?.trim();
    if (!configuredUrl) return;

    const webUrl = this.context.pageContext.web.absoluteUrl.endsWith('/')
      ? this.context.pageContext.web.absoluteUrl
      : `${this.context.pageContext.web.absoluteUrl}/`;
    const url = new URL(configuredUrl, webUrl);
    if (url.origin !== window.location.origin) {
      throw new Error('The SOL DMS configuration file must be hosted on the current SharePoint origin.');
    }

    const response = await this.context.spHttpClient.get(url.toString(), SPHttpClient.configurations.v1);
    if (!response.ok) {
      throw new Error(`SOL DMS configuration returned HTTP ${response.status}.`);
    }
    const config = await response.json() as Partial<SolDmsRuntimeConfig>;
    if (config.mode !== 'http' || !config.endpoints || typeof config.endpoints !== 'object') {
      throw new Error('SOL DMS configuration must declare mode "http" and an endpoints object.');
    }
    this._runtimeConfig = config as SolDmsRuntimeConfig;
  }

  private async _execute(endpoint: OperationEndpoint, init: RequestInit): Promise<Response> {
    const url = new URL(endpoint.url, this.context.pageContext.web.absoluteUrl).toString();
    if (endpoint.auth === 'entra') {
      if (!endpoint.resource) throw new Error('An Entra-protected endpoint must declare its application resource URI.');
      const client = await this.context.aadHttpClientFactory.getClient(endpoint.resource);
      return await client.fetch(url, AadHttpClient.configurations.v1, init) as unknown as Response;
    }
    if (endpoint.auth === 'browser') {
      const resolved = new URL(url);
      if (resolved.origin !== window.location.origin) throw new Error('Browser endpoints must be hosted on the current SharePoint origin.');
      return fetch(resolved, { credentials: 'same-origin', ...init });
    }
    return await this.context.spHttpClient.fetch(url, SPHttpClient.configurations.v1, init) as unknown as Response;
  }

  protected onDispose(): void {
    ReactDom.unmountComponentAtNode(this.domElement);
  }

  protected get dataVersion(): Version {
    return Version.parse('1.0');
  }

  protected getPropertyPaneConfiguration(): IPropertyPaneConfiguration {
    return {
      pages: [
        {
          header: { description: 'Configure the tenant-owned SOL DMS service manifest.' },
          groups: [
            {
              groupName: 'Environment configuration',
              groupFields: [
                PropertyPaneTextField('configurationUrl', {
                  label: 'Runtime configuration URL',
                  description: 'Site-relative URL to the SOL DMS service manifest. Do not store credentials in this file.'
                })
              ]
            }
          ]
        }
      ]
    };
  }
}
