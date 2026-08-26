import * as React from 'react';
import type { ISolDmsProps } from './ISolDmsProps';
import { App } from '../../../solDmsApp/app/App';
import './SolDms.module.scss';

export default class SolDms extends React.Component<ISolDmsProps> {
  public render(): React.ReactElement<ISolDmsProps> {
    return <App services={this.props.services} />;
  }
}
